# Architecture UniStream

## Layers

```
screens/        UI (StatefulWidget + ConsumerWidget)
    |
providers/      State management (Riverpod StateNotifier)
    |
services/       Business logic (API, sync, watch progress)
    |
models/         Data classes (Freezed)
    |
core/           Config, theme, logger, storage keys
```

## State Management (Riverpod)

Chaque domaine a son propre provider :

| Provider | Type | Rôle |
|----------|------|------|
| `configProvider` | StateNotifier | Profils, serveur actif |
| `favoritesProvider` | StateNotifier | Favoris (Set keys + List items) |
| `watchlistProvider` | StateNotifier | Liste "à regarder" |
| `collectionsProvider` | StateNotifier | Collections utilisateur |
| `watchProgressProvider` | FutureProvider | Ratios de progression |
| `continueWatchingProvider` | FutureProvider | Items en cours |
| `connectivityProvider` | StreamProvider | Statut réseau |
| `parentalProvider` | StateNotifier | PIN + catégories bloquées |
| `paginatedStreamsProvider` | StateNotifier | Pagination lazy-load |

## Data Flow

```
User Action
    ↓
Provider.method()
    ↓
1. Update in-memory state
2. Persist to SharedPreferences (local-first)
3. Push to Supabase (fire-and-forget)
    ↓
UI rebuilt via ref.watch()
```

### Sync bidirectionnelle

- **Pull au démarrage** : `SyncService.pullAll()` → merge dans providers locaux
- **Realtime** : Supabase channels → callback → re-pull + merge
- **Push** : Chaque mutation locale → `SyncService.pushX()` (debounced 500ms)
- **Offline** : Tout fonctionne localement, sync reprend au retour online

### Merge strategy

Union-based : les données distantes remplissent les lacunes locales, les données locales ont priorité en cas de conflit.

## API (Xtream Codes)

Client statique `XtreamApi` avec :
- **Retry** : Backoff exponentiel + jitter (configurable via settings)
- **Cache EPG** : In-memory (TTL 30min, max 500 entrées) + persisté sur disque
- **Cache streams** : TTL 5min, max 100 entrées
- **Error typing** : `ApiErrorKey` enum → localisé au niveau UI

## Video Playback

- **media_kit** (libmpv) pour la lecture cross-platform
- **Mini-player** : Overlay global avec suivi position
- **Raccourcis clavier** : Via `HardwareKeyboard` + handler dédié
- **Channel zapping** : Contrôleur séparé (`ChannelZappingController`)

## Profils

- Multi-profil avec credentials IPTV séparés
- Toutes les données scopées par `activeProfileId`
- PIN optionnel (SHA-256 hash via package `crypto`)
- Stockage sécurisé pour les mots de passe (Keychain macOS + fallback)

## Persistance

| Store | Usage |
|-------|-------|
| SharedPreferences | Favoris, watchlist, collections, progression, préférences UI, cache EPG |
| FlutterSecureStorage | Mots de passe profil (Keychain macOS) |
| Supabase PostgreSQL | Sync cross-device (tables: user_favorites, user_collections, user_watch_progress) |
