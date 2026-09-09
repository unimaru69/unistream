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

## Lecture saccadée sur Linux : plafond de débit vers le panel

Symptôme (iMac Fedora, AppImage release, 2026-09-08/09) : la lecture se met
en pause ~1 s toutes les quelques secondes, en live comme en VOD, avec une
sévérité proportionnelle à la résolution — SD propre, HD occasionnel, FHD
systématique.

**Cause mesurée : le panel ne sert cette machine qu'à ~6,4 Mb/s. L'app
n'est pas en cause.** Mesuré avec `curl`, sans player, sans décodeur et
sans Flutter dans l'équation :

```
$ curl -L -o /dev/null -w 'debit: %{speed_download} octets/s\n' --max-time 20 'URL_D_UN_FILM'
debit: 796430 octets/s        ← 6,4 Mb/s, et « Current Speed » retombé à 248 k en fin de transfert
```

C'est le même ordre de grandeur que ce que l'app obtient (3 à 6 Mb/s), donc
mpv exploite le tuyau tel qu'il est. Et ça explique exactement la
progression avec la résolution : un live FHD demande ~5,9 Mb/s de vidéo
plus l'audio et l'encapsulation TS, soit ~6,3-6,5 Mb/s — pile sur le
plafond, aucune marge, donc une coupure toutes les quelques secondes. Une
chaîne SD ou HD à 1,5-3 Mb/s garde de la marge et passe proprement.

### Ce que ça n'est pas

- **Le lien Wi-Fi, le pilote, l'économie d'énergie.** La même machine tire
  **120 Mb/s** depuis GitHub sur ce même Wi-Fi (119 Mo en 8 s lors d'un
  téléchargement d'AppImage), `tx bitrate` négocié à 702 Mb/s, `power_save
  off`, pilote propriétaire `wl` en place. Tous ces leviers sont épuisés :
  le plafond est propre au chemin vers *ce* panel.
- **La configuration du cache.** Le relevé `UNISTREAM_PLAYER_DIAG=1` sur un
  film — le seul test qui mesure le tuyau, un live étant poussé à ~1× temps
  réel — montre une réserve qui plafonne à 4,7 s puis retombe à zéro. Elle
  est limitée par la livraison, pas par `demuxer-max-bytes` (32 Mo ≈ 55 s à
  4,7 Mb/s) ni par `cache-secs` (déjà à l'infini). Les augmenter ne
  changerait rien.
- **Le décodage et la présentation.** Sur 43 s de relevé : `dec-drop=+0`,
  `vo-drop=+0`, `vo-delay=+0`, `vf-fps` exactement 24,000 (et 50,000 sur le
  live 1080p50), `avsync` sous la milliseconde. Parfaits, `hwdec=no`
  compris.

### Reste à départager

Le Mac lit ces mêmes flux sans coupure sur le même réseau. Pour savoir si
le plafond est propre à l'hôte Fedora ou commun aux deux, lancer le
**même `curl` depuis le Mac** : un débit franchement supérieur désigne le
chemin de la Fedora (auquel cas comparer `curl -4` et `curl -6` — une IPv6
mal routée vers le panel donne exactement ce profil « même box, deux
machines, une seule lente ») ; un débit équivalent désigne le panel ou le
transit de l'opérateur, et il n'y a alors rien à faire côté machine.

Dans tous les cas l'échappatoire est la définition : sur un plafond de
6,4 Mb/s, regarder la variante HD de la chaîne n'est pas un pis-aller,
c'est le débit disponible.

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
