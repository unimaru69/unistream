# UniStream — Design System

Cohérence entre l'app Flutter (iPhone, iPad, macOS, Windows, Linux, Android)
et l'app native Swift tvOS. Code séparé, marque unique.

## North star visuel (v2 — 2026-05)

UniStream adopte un design language **Apple TV+ / Strimr** :
- True-black canvas, surfaces lift par couches
- Typographie **SF Pro Display** (système Apple), tracking serré
- Backdrops TMDB plein écran sticky derrière le contenu
- Focus engine = scale 1.10 + ombre profonde + ring teal subtil
- Glassmorphism léger sur les modales (`.ultraThinMaterial`)
- Mouvement lent et premium (0.18s à 0.4s easeOut)

Référence visuelle : Apple TV+ Home, Strimr (https://strimr.app), Plex
en mode "cinematic".

## Couleurs

Source de vérité : `tvos/UniStreamTV/UniStreamTV/Views/Components/DesignSystem.swift::DS.Colour`
+ `lib/core/colors.dart::AppColors`. Les deux fichiers doivent rester en
lock-step.

| Rôle | Hex | Usage |
|------|-----|-------|
| Background | `#000000` | Canvas principal — true black |
| Surface | `#141414` | Cartes, panneaux soulevés |
| Surface elevated | `#1C1C1E` | Cartes nested, hover preview |
| Accent (teal) | `#1B6B8A` | Focus ring, CTAs primaires, "À LA UNE" |
| Accent light | `#2A8AB0` | Hover / variant clair |
| Accent warm | `#FF6B5B` | "En direct", "Nouveau" — usage très parcimonieux |
| Error | `#FF453A` | Erreurs, destructif (système Apple) |
| Success | `#32D74B` | "Vu", confirmations (système Apple) |
| Warning | `#FFD60A` | Alertes EPG, "Bientôt expiré" |

Texte sur fond sombre : `Color.white` à 1.0 / 0.72 / 0.50 / 0.30 d'opacité
(primary / secondary / tertiary / disabled).

**Règles :**
- Thème sombre par défaut partout. macOS/tvOS peuvent rendre un mode light
  natif si le système le réclame, mais on ne forcera jamais le light.
- Le teal `#1B6B8A` reste la signature unique. Pas de gradients
  arc-en-ciel, pas de palette riche — la richesse vient des backdrops
  TMDB, pas du chrome.

## Typographie (SF Pro Display)

Source : `DS.Typography` (Swift) — pour Flutter, utiliser le `TextTheme`
par défaut qui résout sur SF Pro sur les plateformes Apple.

| Token | Taille | Poids | Usage |
|-------|--------|-------|-------|
| `displayHero` | 56 | bold | Titre du hero "À LA UNE" |
| `display` | 44 | bold | Headers très grands (rares) |
| `title1` | 32 | bold | Titres de page / écran |
| `title2` | 24 | semibold | Sous-titres ("Continuer à regarder", "Catégories") |
| `title3` | 20 | semibold | Titres de cartes, dialogues |
| `body` | 17 | regular | Corps |
| `bodyEmphasised` | 17 | semibold | CTAs, focus titles |
| `caption` | 13 | regular | Métadonnées (année, durée, genre) |
| `label` | 13 | semibold smallcaps | Badges ("À LA UNE", "FILM", "VU") |

## Spacing (4-pt grid)

`DS.Spacing` / `AppSpacing` :
`xxs=4 / xs=8 / sm=12 / md=16 / lg=24 / xl=32 / xxl=48 / xxxl=64 / huge=96`

Padding écran tvOS : 60pt horizontal (safe area). 40pt pour les détails
de split view. Sections séparées de 48pt verticaux.

## Radii

| Token | Valeur | Usage |
|-------|--------|-------|
| `card` | 12pt | Posters, rangées |
| `hero` | 20pt | Hero, détail, modales |
| `pill` | capsule | Pills, chips, badges |
| `tag` | 6pt | Tags petits, métadonnées |

## Focus (tvOS)

Tout focusable utilise `focusCardEffect(isFocused:)` ou un `Button` avec
le `tvCard` style :
- Scale 1.10
- Ombre y=8 / radius=24 / opacity=0.5
- Ring teal opacity 0.7 / 2pt épaisseur
- Animation easeOut 0.18s

## Mouvement

| Token | Durée | Usage |
|-------|-------|-------|
| `quick` | 0.15s | Focus, micro-interactions |
| `standard` | 0.25s | Hover, transitions de cartes |
| `slow` | 0.40s | Crossfades de backdrop, hero rotation |
| `spring` | 0.45s response | Modales, présentations |

Toujours easeOut. Jamais d'`easeInOut` (sentiment "rebondit"), jamais de
`linear` (sauf timeline scrub player).

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
