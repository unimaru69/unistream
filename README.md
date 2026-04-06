# UniStream

Application de streaming IPTV multiplateforme construite avec Flutter. Supporte les chaînes Live, VOD et Séries via le protocole Xtream Codes.

## Fonctionnalités

- **Live TV** : Chaînes en direct avec EPG, catch-up/timeshift, zapping rapide
- **VOD** : Films avec page de détail (poster, synopsis, rating), reprise de lecture
- **Séries** : Navigation par saisons, auto-play épisode suivant, progression par épisode
- **Multi-profils** : Profils IPTV multiples avec avatars, PIN optionnel
- **Contrôle parental** : Blocage de catégories par profil, PIN global
- **Synchronisation** : Favoris, watchlist, progression cross-device via Supabase
- **Mini-player** : Lecture en overlay pendant la navigation
- **EPG** : Guide TV grille 24h, rappels, recherche dans les programmes
- **Thèmes** : Dark et Light, personnalisables
- **Localisation** : Français et Anglais
- **Desktop** : Raccourcis clavier, gestion de fenêtre, sidebar redimensionnable

## Plateformes

| Plateforme | Statut | Package |
|------------|--------|---------|
| macOS | Principal | DMG |
| Windows | Natif | MSIX |
| Linux | Natif | AppImage |
| iOS | Simulateur | IPA |

## Prérequis

- Flutter SDK >= 3.11.4
- Dart >= 3.3
- Xcode (macOS/iOS)
- Visual Studio (Windows)

## Démarrage rapide

```bash
# Cloner le projet
git clone https://github.com/unimaru69/unistream.git
cd unistream

# Installer les dépendances
flutter pub get

# Générer le code (Freezed + JSON serializable)
flutter pub run build_runner build --delete-conflicting-outputs

# Lancer en mode debug
flutter run -d macos    # ou windows, linux
```

## Tests

```bash
# Tests unitaires + widget (588+ tests)
flutter test

# Analyse statique
flutter analyze

# Tests d'intégration
flutter test integration_test/
```

## Architecture

Voir [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) pour le détail complet.

```
lib/
  core/         # Config, thème, logger, storage keys
  models/       # Modèles Freezed (Channel, VodItem, SeriesItem, etc.)
  providers/    # State management Riverpod
  services/     # API Xtream, sync Supabase, watch progress, EPG
  screens/      # Écrans (home, player, search, settings, EPG, etc.)
  widgets/      # Widgets réutilisables
  l10n/         # Localisation FR + EN
  utils/        # Helpers (routes, snackbar, stream helpers)
```

## Build & Release

Voir [docs/RELEASE.md](docs/RELEASE.md) pour les instructions de packaging par plateforme.

## Licence

Projet privé.
