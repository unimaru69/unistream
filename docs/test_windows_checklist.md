# UniStream — Checklist test fonctionnel Windows

Cible : validation d'un build Windows natif sur une machine de test. À utiliser conjointement avec `tools/test_windows.ps1`.

## 0. Pré-requis machine

- [ ] Flutter SDK ≥ 3.11.4 — `flutter --version`
- [ ] Visual Studio 2022, workload *Desktop development with C++*
- [ ] Git configuré
- [ ] `flutter doctor -v` : section Windows et Visual Studio en ✓

## 1. Build & lancement

- [ ] `git pull` OK, pas de conflit
- [ ] `flutter clean && flutter pub get` sans erreur
- [ ] `flutter build windows --release` se termine sans erreur
- [ ] `unistream.exe` démarre (release) depuis `build\windows\x64\runner\Release\`
- [ ] Pas de console fantôme en release
- [ ] Fenêtre 1280×800 au premier lancement
- [ ] Logo / splash affiché correctement
- [ ] Aucun crash dans les 30 premières secondes

## 2. Fenêtre & persistance

- [ ] Resize manuel de la fenêtre
- [ ] Déplacement de la fenêtre
- [ ] Fermeture puis relance → taille et position restaurées
- [ ] Min size respecté (800×500)

## 3. Profils & mots de passe (secure storage)

- [ ] Création d'un profil avec login/password Xtream
- [ ] Mot de passe masqué à la saisie
- [ ] Relance app → profil rechargé, mot de passe récupéré depuis Windows Credential Manager
- [ ] Suppression profil → entrée Credential Manager nettoyée
- [ ] Pas d'erreur silencieuse dans les logs sur les opérations secure storage

## 4. Lecture vidéo (media_kit + libmpv)

- [ ] DLL media_kit présentes dans le dossier Release à côté du .exe
- [ ] Live TV (flux HLS) : play, son, image
- [ ] VOD (MP4) : play, seek, pause
- [ ] Série (épisode) : play, progression sauvegardée
- [ ] Changement de chaîne rapide (5x) → pas de fuite mémoire ni freeze
- [ ] Plein écran (F / double-clic)
- [ ] Sortie plein écran (Esc via HardwareKeyboard)
- [ ] Volume / mute
- [ ] Sous-titres si dispo sur le flux

## 5. Mini-player

- [ ] Navigation vers autre écran pendant lecture → mini-player apparaît
- [ ] Clic sur mini-player → retour en plein écran de lecture
- [ ] Fermeture mini-player → arrêt lecture propre

## 6. Sync Supabase

- [ ] Login Supabase depuis Windows (email/pass ou SSO)
- [ ] Création d'un profil sur Windows → apparaît côté macOS après sync
- [ ] Modification d'un profil côté macOS → répercutée sur Windows
- [ ] App en arrière-plan (fenêtre minimisée) → sync pausée (`_syncPaused`)
- [ ] Retour foreground → sync reprend

## 7. Import / Export

- [ ] Import M3U depuis fichier local (file_picker ouvre dialog Windows natif)
- [ ] Import Xtream via URL
- [ ] Export config → fichier JSON bien écrit dans le dossier choisi
- [ ] Réimport du fichier exporté → état identique

## 8. EPG & notifications

- [ ] EPG se charge pour une chaîne
- [ ] Programmation d'un rappel programme
- [ ] Notification Windows (toast) reçue à l'heure prévue
- [ ] Clic sur la notif → ouvre l'app sur la chaîne concernée

## 9. Raccourcis clavier

- [ ] Esc : sortie plein écran / retour
- [ ] Space : play/pause
- [ ] Flèches gauche/droite : seek (VOD)
- [ ] Flèches haut/bas : volume
- [ ] Shortcuts globaux configurés (Sprint 7) fonctionnels

## 10. i18n

- [ ] Bascule FR → EN depuis Paramètres
- [ ] Redémarrage → langue persistée
- [ ] Aucun placeholder `???` dans l'UI

## 11. Thème

- [ ] Light / Dark / System
- [ ] Persistance après relance

## 12. Observabilité

- [ ] Logs Sentry remontent (si `isSentryEnabled=true` et DSN valide)
- [ ] Pas d'erreur FlutterError non capturée
- [ ] AppLogger produit des logs lisibles en debug

## 13. Performance

- [ ] Scroll liste chaînes (1000+ items) fluide
- [ ] Recherche instantanée sans lag
- [ ] Démarrage à froid < 5 s sur SSD

## 14. Pièges Windows connus à vérifier explicitement

- [ ] Écran noir player → vérifier DLL `media_kit_libs_windows_video` bundlée
- [ ] `flutter_secure_storage_windows` : tester que Credential Manager service tourne (`sc query VaultSvc`)
- [ ] Pas de warning SmartScreen bloquant au premier lancement (ou le documenter pour la release store)

---

## Rapport de bogue

Pour chaque anomalie trouvée, noter :
- Étape de la checklist concernée
- Répro (étapes minimales)
- Logs pertinents (`flutter run` console ou Sentry event ID)
- Screenshot / capture si visuel
