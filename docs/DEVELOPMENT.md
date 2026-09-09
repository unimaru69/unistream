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

## Lecture saccadée sur Linux : débit amont insuffisant

Symptôme (iMac Fedora, AppImage release, 2026-09-08/09) : la lecture se met
en pause ~1 s toutes les quelques secondes, en live comme en VOD, avec une
sévérité proportionnelle à la résolution — SD propre, HD occasionnel, FHD
systématique.

**Cause mesurée : le flux n'arrive pas plus vite qu'il ne se joue.** Rien à
corriger dans l'app ; mpv fait déjà le bon choix (il attend au lieu de
sacrifier des images). Relevé `UNISTREAM_PLAYER_DIAG=1` sur CANAL+ FHD à
21 h 17 :

```
stream   1920x1080 fps=50 pixfmt=yuv420p
pipeline hwdec=no vo=libmpv ao=pulse cache-on-disk=no
         demuxer-max-bytes=33554432 cache-secs=3600000
for-cache=no  cache=0.8s speed=6.8Mb/s bitrate=0.0Mb/s dec-drop=+0 vo-delay=+0 vf-fps=50.000
for-cache=yes cache=0.0s speed=4.0Mb/s bitrate=6.1Mb/s dec-drop=+0 vo-delay=+0 vf-fps=50.000
for-cache=yes cache=0.0s speed=3.5Mb/s bitrate=6.0Mb/s dec-drop=+0 vo-delay=+0 vf-fps=50.000
```

Lecture :

- `speed` (3,5 à 9 Mb/s, l'essentiel entre 4 et 6) oscille **autour** de
  `bitrate` (5,3 à 6,3 Mb/s) au lieu de le dominer. Et `bitrate` ne compte
  que la **vidéo** : l'audio et l'encapsulation TS s'ajoutent par-dessus, le
  déficit réel est donc un peu pire que l'écart affiché.
- `cache` ne dépasse jamais 1,1 s et retombe régulièrement à 0,0 s. Aucune
  réserve ne se constitue, donc le moindre creux devient un `BUFFERING`
  (observé toutes les 4 à 7 s, pour 1 à 2 s).
- `dec-drop=+0` et `vo-delay=+0` sur toute la durée, `vf-fps` exactement
  50,000, `avsync` sous les 2 ms : décodage et présentation sont parfaits.
  Tout ce qui est local est hors de cause.

Un live ne se met de toute façon pas en réserve : le serveur pousse à ~1×
temps réel et on ne peut pas lire au-delà du bord du direct. `cache-secs`
et `demuxer-max-bytes` sont déjà largement dimensionnés (32 Mo ≈ 43 s à
6 Mb/s) — les augmenter ne changerait rien.

### Localiser : la box ou le panel ?

Un `curl` sur l'URL d'un **live** ne discrimine rien (le serveur le
bride aussi à ~1×). Mesurer sur un **film**, que les panels servent aussi
vite que le tuyau l'accepte :

```bash
curl -o /dev/null -w 'debit: %{speed_download} octets/s\n' --max-time 20 'URL_D_UN_FILM'
```

Repère : 6 Mb/s ≈ 750 000 octets/s. Et le test le plus propre reste de
lire la **même chaîne au même instant** depuis le Mac sur le même réseau —
si le Mac passe et la Fedora coupe, c'est le lien de la box (Wi-Fi
Broadcom sous Fedora, notoirement médiocre sur les vieux iMac) ; si les
deux coupent, c'est le panel en heure de pointe.

### Ce que le diagnostic a écarté, et comment

- **Rendu logiciel de media_kit** : le plugin natif annonce son chemin sur
  stderr sans rebuild — `media_kit: VideoOutput: H/W rendering with
  isolated EGL context…` (le cas ici) vs `S/W rendering.`, qui
  signifierait pas de contexte EGL et chaque image recopiée via un buffer
  RGBA 1080p sur le CPU (vérifier alors `glxinfo | grep -i renderer` ≠
  `llvmpipe`).
- **Décodage logiciel** : `top -H -p $(pgrep -f usr/bin/unistream)`, où
  seule la colonne `TIME+` est fiable sur un `top -n 1`. Relevé : ~19 s de
  CPU pour tout le process sur 126 s, threads `av:h264` à 4 s chacun.
- **Impeller** : Flutter 3.41 **ignore** `enable-impeller=false` sur Linux
  (vérifié par l'environnement : `Using the Impeller rendering backend`
  continue de s'afficher), donc Skia n'est plus atteignable — et le même
  flux FHD passait proprement le lendemain matin avec Impeller inchangé.

### Deux pièges de méthode qui ont coûté des allers-retours

1. `VAR=x ./app` doit être **une seule** commande. `VAR=x` seul sur sa
   ligne n'est qu'une affectation de shell non exportée : le process fils
   ne voit rien, et le test paraît négatif sans avoir eu lieu.
2. Sur un symptôme intermittent, ne jamais valider un correctif sans
   vérifier qu'il est **actif**, ni sans comparer à contenu et à heure
   comparables. Mesurer d'abord : les compteurs de mpv désignaient la
   cause dès la première seconde.
