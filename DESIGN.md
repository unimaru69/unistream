# UniStream — Design System

Cohérence entre l'app Flutter (iPhone, iPad, macOS, Windows, Linux, Android)
et l'app native Swift tvOS. Code séparé, marque unique.

## Couleurs

| Rôle | Hex | Usage |
|------|-----|-------|
| Primary (teal) | `#1B6B8A` | Accent, CTAs, sélection |
| Primary hover | `#2A8AB0` | États focus / hover (surtout tvOS focus engine) |
| Dark background | `#0E0B1E` | Fond principal thème sombre |
| Dark surface | `#161230` | Cartes, sections, modales |
| Accent green | `#2E7D32` | Badges positifs ("Replay", "En direct") |
| Error red | `#C62828` | Erreurs, destructif |

**Règles :**
- Thème sombre par défaut sur Flutter ET tvOS
- tvOS peut laisser macOS/tvOS gérer le light mode via SwiftUI natif — pas d'obligation de forcer le dark
- Le teal `#1B6B8A` est la signature visuelle, identique partout

## Terminologie FR (alignée partout)

Ces termes doivent être **identiques** dans les deux apps :

| Concept | Terme canonique | À éviter |
|---------|-----------------|----------|
| Contenu en direct | **Live** | "TV en direct", "Direct" |
| Films à la demande | **Films** | "VOD", "Vidéos" |
| Séries TV | **Séries** | "Shows", "Feuilletons" |
| Mises en favoris | **Favoris** | "Mes favoris", "Coups de cœur" |
| Lecture en cours | **Continuer à regarder** | "Reprendre", "Continuer la lecture" |
| Lectures passées | **Historique** | "Historique de lecture" (OK si contexte), "Déjà vu" |
| À voir plus tard | **À regarder** | "Watchlist", "Ma liste", "Plus tard" |
| Listes personnalisées | **Collections** | "Playlists", "Listes" |
| Guide programmes | **Guide TV** | "EPG", "Programme", "Grille" |
| PIN et blocage | **Contrôle parental** | "Parental", "Contrôle jeunesse" |
| Abonnement payant | **Abonnement** | "Souscription", "Subscription" |

## Terminologie plateforme-spécifique (assumée)

Ces termes suivent les conventions de la plateforme — ne pas aligner de force :

| Concept | Flutter | tvOS |
|---------|---------|------|
| Réglages | **Paramètres** | **Réglages** (convention Apple) |
| Bouton retour | "Retour" | natif Menu button |
| Changer de profil | "Changer de profil" | "Changer de profil" (modal) |

## Iconographie (métaphores partagées)

Mêmes concepts, icônes natives de la plateforme :

| Concept | Flutter (Material) | tvOS (SF Symbols) |
|---------|-------------------|-------------------|
| Favoris | `Icons.favorite` (cœur plein) | `heart.fill` |
| À regarder | `Icons.bookmark` | `bookmark.fill` |
| Historique | `Icons.history` | `clock.arrow.circlepath` |
| Collections | `Icons.folder` | `folder.fill` |
| Contrôle parental | `Icons.lock` | `lock.shield.fill` |
| Recherche | `Icons.search` | `magnifyingglass` |
| Réglages | `Icons.settings` | `gear` |
| Live TV | `Icons.live_tv` | `tv` ou `antenna.radiowaves.left.and.right` |
| Films | `Icons.movie` | `film.fill` |
| Séries | `Icons.tv` | `tv.inset.filled` |

## Ton et voix

- **Direct, court, sans jargon technique IPTV** : on dit "chaîne", pas "flux" ; "serveur", pas "endpoint"
- **Tutoiement** sur les onboardings courts ("Configure ton serveur") — mais **vouvoiement** sur les notifications système et erreurs ("Votre abonnement a expiré")
- **Phrases courtes**, max 2 lignes pour les empty states
- **Emoji parcimonieux** : icônes natives préférées

## Navigation

### Flutter (cross-platform)
- AppBar + toggle 3 segments (Live / Films / Séries)
- Sidebar catégories > 900px, drawer < 900px
- Menu overflow (3 points) sur écran compact

### tvOS (Apple TV)
- Tab bar horizontale : Accueil / Live / Films / Séries / Favoris / Recherche / Réglages
- Sidebar catégories dans chaque section de contenu
- Focus engine natif

**Règle d'or** : un utilisateur qui passe de l'iPhone à l'Apple TV doit
reconnaître UniStream à la palette, aux icônes métaphores et aux noms
d'onglets — sans que l'UI soit identique.

## Différences assumées

Ces différences sont **volontaires** et ne doivent pas être harmonisées :

| Aspect | Flutter | tvOS | Pourquoi |
|--------|---------|------|----------|
| Mini-player | Oui (PiP flottant) | Non | Apple TV n'a pas d'usage multi-tâche |
| Lecteur video | media_kit (libmpv) | VLCKit + AVPlayer | Chaque plateforme utilise le lecteur avec meilleur support natif |
| Raccourcis clavier | Oui (desktop) | Siri Remote + télécommandes tierces | Périphériques différents |
| Notifications EPG | Système (flutter_local_notifications) | In-app toast | tvOS n'autorise pas les push visuelles |
| Top Shelf | N/A | Extension native | Spécifique Apple TV |
| Gestion profils | Multi-profils + PIN | Idem | ✅ Parité fonctionnelle |

## Évolution

Ce document évolue. Chaque PR qui touche à un écran utilisateur doit :
1. Vérifier la terminologie dans le tableau ci-dessus
2. Vérifier la palette
3. Documenter ici toute nouvelle métaphore d'icône
