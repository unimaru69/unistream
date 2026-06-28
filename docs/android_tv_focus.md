# Android TV — Navigation D-pad (focus) : architecture & chantier

Statut : **fondation posée, chantier focus à finir**. Ce doc capture ce qui
marche, ce qu'on a appris en debuggant, et le plan pour rendre la navigation
D-pad robuste.

## TL;DR

L'app était construite *pointer-first* (souris/clavier desktop). Sur Android TV
elle tourne (même APK), l'entrée D-pad arrive bien à Flutter, la détection TV
marche — mais la **navigation au focus n'est pas encore fiable** parce que le
focus ne survit pas aux reconstructions fréquentes de l'UI. C'est un chantier
de *système de focus*, pas une passe de wrapping.

## Ce qui marche (acquis, ne pas régresser)

- **Leanback / manifest** : `uses-feature leanback (required=false)`,
  `touchscreen (required=false)`, `LEANBACK_LAUNCHER`, `android:banner`
  (`res/drawable/tv_banner.xml`). L'app apparaît sur le launcher TV.
- **Détection** : `lib/core/form_factor.dart` → `FormFactorInfo.isAndroidTv`
  (via `device_info_plus` → `systemFeatures` contient `android.software.leanback`).
  Vérifié `true` sur l'AVD Android TV.
- **Highlight** : `FocusManager.instance.highlightStrategy = alwaysTraditional`
  posé sur TV dans `main.dart` (sinon Android démarre en mode `touch` et le
  halo de focus est invisible).
- **Densité 10-foot** : paddings élargis + halo de focus épaissi dans
  `lib/core/design_tokens.dart` (gated `isAndroidTv`).
- **Player** : D-pad center (`LogicalKeyboardKey.select`) → play/pause ;
  flèches → seek/volume/zapping (déjà géré par `player_keyboard_handler.dart`) ;
  `_isDesktop` étendu à la TV (pas de gesture seek).
- **Widgets focusables** : `lib/widgets/dpad_focusable.dart` (`DpadFocusable`)
  enveloppe les tuiles existantes (Accueil, sidebar, détails, carrousels) pour
  les rendre focusables + activables (Enter/Select) **sans** changer leur
  visuel — le focus alimente le même `onHover`/`_setHover` que la souris. La
  grille (`stream_list.dart`) utilise `FocusableActionDetector` directement.
- **Hero** : rotation auto **désactivée sur TV** (`home_hero.dart`) — elle
  détruisait le FocusNode focalisé toutes les 8 s via l'`AnimatedSwitcher`.

## Diagnostic empirique (ce qu'on a prouvé sur l'AVD)

Avec des logs temporaires (retirés depuis) :

1. **L'entrée fonctionne** : les touches D-pad arrivent à Flutter en tant que
   `Arrow Up/Down/Left/Right` + `Select`. (Le pad de l'émulateur ou
   `adb shell input keyevent 19/20/21/22/23` les injecte.)
2. **`isAndroidTv=true`**, highlight `alwaysTraditional` posé.
3. **Le focus peut être planté** : `FocusScope.of(context).nextFocus()`
   retourne `true` et focalise un vrai nœud.
4. **MAIS le focus ne survit pas** : après un rebuild (connectivité, wallpaper
   ambiant, lookups TMDB, AnimatedSwitcher…), le widget focalisé est *remplacé*,
   son `FocusNode` implicite est *disposé*, et `primaryFocus` retombe à `null`.
5. **Traversée directionnelle cassée sans ancrage** : `focusInDirection` a
   besoin d'un **nœud enfant focalisé** comme point d'ancrage géométrique.
   Depuis un scope nu (`_ModalScope`), Bas/Droite → `null`. Donc dès que le
   focus est perdu, les flèches ne font plus rien.

Conclusion : il faut (a) **retenir** le focus à travers les rebuilds et
(b) garantir un **nœud enfant** focalisé en permanence.

## Fondation livrée : `TvFocusScope`

`lib/core/tv_focus.dart`. Sur non-TV = pass-through. Sur TV :
- enveloppe l'écran dans un `FocusTraversalGroup` (scope la traversée) ;
- **plante** le focus initial après le 1er frame (`nextFocus`, avec retry tant
  que le contenu async n'est pas chargé) ;
- **auto-heal** : écoute `FocusManager` ; quand `primaryFocus` retombe à
  null/scope, re-plante au frame suivant.

Câblé sur le home (`home_screen.dart` : `return TvFocusScope(child: HomeKeyboardHandler(...))`).

⚠️ L'auto-heal re-focalise le **premier** focusable, pas l'item où on était.
C'est une béquille : ça évite le blocage total, mais le focus peut sauter à
l'item 1 après un rebuild. La vraie solution est ci-dessous.

## Chantier restant (le "focus complet")

1. **Restauration du focus par contenu** (priorité 1). Donner aux widgets
   navigables des `FocusNode` **stables et possédés** (créés dans un `State`),
   pas les nodes implicites de `FocusableActionDetector`. Mémoriser « la tuile
   de l'item X » et restaurer le focus dessus après rebuild, au lieu de
   `nextFocus`. → upgrade de `DpadFocusable` pour accepter un `focusNode`
   fourni + une clé d'identité, et un registre par écran.

2. **Stabiliser les rebuilds**. Sur TV, geler/atténuer les sources de rebuild
   qui remplacent des widgets focalisés : wallpaper ambiant (`AmbientWallpaper`),
   `AnimatedSwitcher` du hero backdrop, rebuilds déclenchés par les lookups
   TMDB. Idéalement, ne pas remplacer l'élément focalisé (garder une clé
   stable) plutôt que de le re-créer.

3. **Politique de traversée 2-D**. Les rangées horizontales imbriquées dans une
   `ListView` verticale peuvent tromper `ReadingOrderTraversalPolicy`. Mettre
   un `FocusTraversalGroup` **par rangée**, et/ou écrire une politique
   directionnelle adaptée (Haut/Bas = changer de rangée, Gauche/Droite =
   défiler dans la rangée).

4. **Scroll-into-view systématique**. Les `ListView`/`GridView` lazy ne
   construisent que les items visibles → impossible de focaliser hors écran.
   Appeler `Scrollable.ensureVisible` au gain de focus (déjà fait dans la
   grille ; à généraliser aux carrousels).

5. **Focus initial intentionnel par écran**. Définir explicitement le premier
   focus de chaque écran (hero Play sur Accueil, 1ʳᵉ tuile sur la grille, 1er
   bouton sur les détails) plutôt que « premier focusable ».

## Bugs UI TV connus (à corriger)

- **Overflow `focused_item_preview.dart:99`** : `RenderFlex overflowed by
  335px` en densité TV. La Row du panneau preview dépasse — ajouter
  `Expanded`/`Flexible` ou contraindre la largeur sur TV.

## Tester en local

- **AVD** : image **arm64-v8a** obligatoire sur Mac Apple Silicon
  (`system-images;android-34;android-tv;arm64-v8a`). Les images x86 ne
  démarrent pas (émulateur sort en code 1).
- **Ajout de plugin natif** (ex. `device_info_plus`) → **rebuild complet**
  (`q` puis `flutter run`), pas un hot restart.
- **Injecter le D-pad** sans télécommande :
  `adb shell input keyevent 20` (bas), `19` (haut), `21` (gauche),
  `22` (droite), `23` (center/select), `4` (back).
- **Serveur démo** : `demo.unimaru.fr` peut être injoignable depuis l'émulateur
  → l'app bascule en `OfflineContent` (peu de focusables). Tester contre un
  serveur Xtream joignable, ou vérifier la connectivité de l'AVD, pour valider
  les vrais écrans Accueil/grille.
- **RevenueCat** : volontairement désactivé sur Android tant que la clé
  Google Play est le placeholder (`purchase_service.dart`) — sans impact sur le
  focus, l'accès reste débloqué (FeatureAccess.canUse=true).
