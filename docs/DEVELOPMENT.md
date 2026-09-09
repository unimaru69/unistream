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

## Lecture saccadée sur Linux : le lien réseau de la machine

Symptôme (iMac Fedora, AppImage release, 2026-09-08/09) : la lecture se met
en pause ~1 s toutes les quelques secondes, en live comme en VOD, avec une
sévérité proportionnelle à la résolution — SD propre, HD occasionnel, FHD
systématique.

**Cause mesurée : le chemin réseau de cette machine plafonne autour de
4-5 Mb/s. Rien à corriger dans l'app.** mpv fait déjà le bon choix (il
attend au lieu de sacrifier des images), et le décodage comme la
présentation sont irréprochables.

La mesure décisive est le relevé `UNISTREAM_PLAYER_DIAG=1` **sur un film**,
pas sur un live : un live est poussé à ~1× temps réel et ne dit rien du
tuyau, alors qu'un VOD est servi aussi vite que la liaison l'accepte —
`speed` doit donc écraser `bitrate` et `cache` grimper jusqu'à remplir les
32 Mo (≈ 55 s à 4,7 Mb/s). Observé sur un film 24 fps :

```
 2.0s cache=2.3s speed=9.9Mb/s  ← pointe d'ouverture
 3.0s cache=1.9s speed=12.1Mb/s
 6.0s cache=0.2s speed=3.5Mb/s
 7.9s BUFFERING start
21.0s cache=4.4s speed=5.0Mb/s bitrate=4.7Mb/s   ← réserve maximale atteinte
38.0s cache=0.0s speed=3.2Mb/s bitrate=4.6Mb/s
38.1s BUFFERING start
```

Lecture :

- la réserve ne dépasse jamais **4,7 s** et retombe à zéro : le cache est
  limité par la livraison, pas par sa configuration ;
- `speed` tient 3 à 6 Mb/s en régime, pour un film à 4,6-4,7 Mb/s — aucune
  marge, d'où les `BUFFERING` ;
- mais la pointe d'ouverture à **12,1 Mb/s** prouve que le serveur *peut*
  dépasser le bitrate. Le panel n'est donc pas le facteur limitant ;
- `dec-drop=+0`, `vo-drop=+0`, `vo-delay=+0` sur les 43 s, `vf-fps`
  exactement 24,000, `avsync` sous la milliseconde : décodage et
  présentation parfaits, y compris en `hwdec=no`.

Et le même compte s'écrit en live (CANAL+ FHD 1080p50) : `speed` 3,5-6 Mb/s
contre un `bitrate` vidéo de 5,3-6,3 Mb/s — auquel s'ajoutent l'audio et
l'encapsulation TS, donc le déficit réel est pire que l'écart affiché.

Le Mac, sur le même réseau et le même panel, lit ces flux sans coupure. Le
plafond est donc propre à cette machine : liaison Wi-Fi (les Broadcom sous
Fedora sont médiocres sur ces vieux iMac), ou route dégradée. À confirmer
hors app — `curl -L` sur l'URL d'un film, qui retire player, décodeur et
Flutter de l'équation — puis à traiter côté système : câble Ethernet,
bande Wi-Fi, ou `curl -4` contre `curl -6` si une IPv6 mal routée vers le
panel est en cause.

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
