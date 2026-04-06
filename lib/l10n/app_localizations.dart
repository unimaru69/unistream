import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @annuler.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get annuler;

  /// No description provided for @fermer.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get fermer;

  /// No description provided for @supprimer.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get supprimer;

  /// No description provided for @enregistrer.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get enregistrer;

  /// No description provided for @champObligatoire.
  ///
  /// In fr, this message translates to:
  /// **'Ce champ est obligatoire'**
  String get champObligatoire;

  /// No description provided for @urlInvalide.
  ///
  /// In fr, this message translates to:
  /// **'URL invalide (ex: http://...)'**
  String get urlInvalide;

  /// No description provided for @creer.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get creer;

  /// No description provided for @connexion.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get connexion;

  /// No description provided for @effacer.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get effacer;

  /// No description provided for @oui.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get oui;

  /// No description provided for @non.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get non;

  /// No description provided for @favoris.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get favoris;

  /// No description provided for @historique.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get historique;

  /// No description provided for @parametres.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get parametres;

  /// No description provided for @rechercher.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get rechercher;

  /// No description provided for @guideTV.
  ///
  /// In fr, this message translates to:
  /// **'Guide TV'**
  String get guideTV;

  /// No description provided for @profils.
  ///
  /// In fr, this message translates to:
  /// **'Profils'**
  String get profils;

  /// No description provided for @rechercherCatalogue.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans tout le catalogue…'**
  String get rechercherCatalogue;

  /// No description provided for @rechercherDots.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher...'**
  String get rechercherDots;

  /// No description provided for @aucunResultat.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get aucunResultat;

  /// No description provided for @tapeAuMoins2.
  ///
  /// In fr, this message translates to:
  /// **'Tape au moins 2 caractères'**
  String get tapeAuMoins2;

  /// No description provided for @aucunHistorique.
  ///
  /// In fr, this message translates to:
  /// **'Aucun historique'**
  String get aucunHistorique;

  /// No description provided for @aucunProgramme.
  ///
  /// In fr, this message translates to:
  /// **'Aucun programme'**
  String get aucunProgramme;

  /// No description provided for @selectionneCategorie.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionne une catégorie'**
  String get selectionneCategorie;

  /// No description provided for @selectionneSaison.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionne une saison'**
  String get selectionneSaison;

  /// No description provided for @aucuneDonneesCache.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée en cache disponible'**
  String get aucuneDonneesCache;

  /// No description provided for @connexionRequise.
  ///
  /// In fr, this message translates to:
  /// **'Connexion requise'**
  String get connexionRequise;

  /// No description provided for @reprendreLecture.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre la lecture ?'**
  String get reprendreLecture;

  /// No description provided for @depuisDebut.
  ///
  /// In fr, this message translates to:
  /// **'Depuis le début'**
  String get depuisDebut;

  /// No description provided for @episodeSuivant.
  ///
  /// In fr, this message translates to:
  /// **'Épisode suivant'**
  String get episodeSuivant;

  /// No description provided for @vitesseLecture.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse de lecture'**
  String get vitesseLecture;

  /// No description provided for @ratioAspect.
  ///
  /// In fr, this message translates to:
  /// **'Ratio d\'aspect'**
  String get ratioAspect;

  /// No description provided for @minuterieVeille.
  ///
  /// In fr, this message translates to:
  /// **'Minuterie de veille'**
  String get minuterieVeille;

  /// No description provided for @styleSousTitres.
  ///
  /// In fr, this message translates to:
  /// **'Style des sous-titres'**
  String get styleSousTitres;

  /// No description provided for @nouvelleCollection.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle collection'**
  String get nouvelleCollection;

  /// No description provided for @creerCollection.
  ///
  /// In fr, this message translates to:
  /// **'Créer collection'**
  String get creerCollection;

  /// No description provided for @ajouterCollection.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à une collection'**
  String get ajouterCollection;

  /// No description provided for @nouveauProfil.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau profil'**
  String get nouveauProfil;

  /// No description provided for @modifierProfil.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get modifierProfil;

  /// No description provided for @supprimerProfil.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce profil ?'**
  String get supprimerProfil;

  /// No description provided for @ajouterProfil.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un profil'**
  String get ajouterProfil;

  /// No description provided for @testerEtAjouter.
  ///
  /// In fr, this message translates to:
  /// **'Tester et ajouter'**
  String get testerEtAjouter;

  /// No description provided for @tousChampRequis.
  ///
  /// In fr, this message translates to:
  /// **'Tous les champs sont requis'**
  String get tousChampRequis;

  /// No description provided for @authEchouee.
  ///
  /// In fr, this message translates to:
  /// **'Authentification échouée'**
  String get authEchouee;

  /// No description provided for @importExport.
  ///
  /// In fr, this message translates to:
  /// **'IMPORT / EXPORT'**
  String get importExport;

  /// No description provided for @apparence.
  ///
  /// In fr, this message translates to:
  /// **'APPARENCE'**
  String get apparence;

  /// No description provided for @langues.
  ///
  /// In fr, this message translates to:
  /// **'LANGUES'**
  String get langues;

  /// No description provided for @cacheSection.
  ///
  /// In fr, this message translates to:
  /// **'CACHE'**
  String get cacheSection;

  /// No description provided for @effacerHistorique.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l\'historique'**
  String get effacerHistorique;

  /// No description provided for @effacerHistoireQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l\'historique ?'**
  String get effacerHistoireQuestion;

  /// No description provided for @actionIrreversible.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible.'**
  String get actionIrreversible;

  /// No description provided for @entreeSupprimee.
  ///
  /// In fr, this message translates to:
  /// **'Entrée supprimée'**
  String get entreeSupprimee;

  /// No description provided for @sansTitre.
  ///
  /// In fr, this message translates to:
  /// **'Sans titre'**
  String get sansTitre;

  /// No description provided for @raccourcisClavier.
  ///
  /// In fr, this message translates to:
  /// **'Raccourcis clavier'**
  String get raccourcisClavier;

  /// No description provided for @continuerRegarder.
  ///
  /// In fr, this message translates to:
  /// **'Continuer à regarder'**
  String get continuerRegarder;

  /// No description provided for @favorisPremier.
  ///
  /// In fr, this message translates to:
  /// **'Favoris en premier'**
  String get favorisPremier;

  /// No description provided for @trier.
  ///
  /// In fr, this message translates to:
  /// **'Trier'**
  String get trier;

  /// No description provided for @filtrerChaines.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer les chaînes...'**
  String get filtrerChaines;

  /// No description provided for @annulerSelection.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la sélection'**
  String get annulerSelection;

  /// No description provided for @selectionnerPourCollection.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner pour créer une collection'**
  String get selectionnerPourCollection;

  /// No description provided for @configureServeur.
  ///
  /// In fr, this message translates to:
  /// **'Configure ton serveur IPTV pour commencer'**
  String get configureServeur;

  /// No description provided for @gererProfils.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les profils'**
  String get gererProfils;

  /// No description provided for @serverUrl.
  ///
  /// In fr, this message translates to:
  /// **'URL du serveur'**
  String get serverUrl;

  /// No description provided for @serverUrlHint.
  ///
  /// In fr, this message translates to:
  /// **'http://monserveur.com:8080'**
  String get serverUrlHint;

  /// No description provided for @nomUtilisateur.
  ///
  /// In fr, this message translates to:
  /// **'Nom d\'utilisateur'**
  String get nomUtilisateur;

  /// No description provided for @motDePasse.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get motDePasse;

  /// No description provided for @configSauvegardee.
  ///
  /// In fr, this message translates to:
  /// **'Configuration sauvegardée'**
  String get configSauvegardee;

  /// No description provided for @importM3U.
  ///
  /// In fr, this message translates to:
  /// **'Import M3U'**
  String get importM3U;

  /// No description provided for @exportFavoris.
  ///
  /// In fr, this message translates to:
  /// **'Export favoris (.m3u)'**
  String get exportFavoris;

  /// No description provided for @sauvegarderConfig.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder config (JSON)'**
  String get sauvegarderConfig;

  /// No description provided for @restaurerConfig.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer config (JSON)'**
  String get restaurerConfig;

  /// No description provided for @cacheEpgVide.
  ///
  /// In fr, this message translates to:
  /// **'Cache EPG vidé'**
  String get cacheEpgVide;

  /// No description provided for @cacheImagesVide.
  ///
  /// In fr, this message translates to:
  /// **'Cache images vidé'**
  String get cacheImagesVide;

  /// No description provided for @themeMode.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get themeMode;

  /// No description provided for @themeSombre.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeSombre;

  /// No description provided for @themeClair.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeClair;

  /// No description provided for @themeSysteme.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get themeSysteme;

  /// No description provided for @langueAudio.
  ///
  /// In fr, this message translates to:
  /// **'Langue audio'**
  String get langueAudio;

  /// No description provided for @langueSousTitres.
  ///
  /// In fr, this message translates to:
  /// **'Langue sous-titres'**
  String get langueSousTitres;

  /// No description provided for @langueInterface.
  ///
  /// In fr, this message translates to:
  /// **'Langue interface'**
  String get langueInterface;

  /// No description provided for @original.
  ///
  /// In fr, this message translates to:
  /// **'Original'**
  String get original;

  /// No description provided for @desactive.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get desactive;

  /// No description provided for @activer.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get activer;

  /// No description provided for @bienvenue.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue sur UniStream'**
  String get bienvenue;

  /// No description provided for @commencer.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get commencer;

  /// No description provided for @errConnexionImpossible.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifiez votre connexion internet.'**
  String get errConnexionImpossible;

  /// No description provided for @errServeurNeRepond.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur ne répond pas. Réessayez dans quelques instants.'**
  String get errServeurNeRepond;

  /// No description provided for @errCommunication.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de communication avec le serveur.'**
  String get errCommunication;

  /// No description provided for @errReponseInvalide.
  ///
  /// In fr, this message translates to:
  /// **'Réponse invalide du serveur.'**
  String get errReponseInvalide;

  /// No description provided for @errIdentifiants.
  ///
  /// In fr, this message translates to:
  /// **'Identifiants incorrects. Vérifiez votre nom d\'utilisateur et mot de passe.'**
  String get errIdentifiants;

  /// No description provided for @errGenerique.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get errGenerique;

  /// No description provided for @entreesImportees.
  ///
  /// In fr, this message translates to:
  /// **'{count} entrées importées'**
  String entreesImportees(int count);

  /// No description provided for @profil.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profil;

  /// No description provided for @nomProfil.
  ///
  /// In fr, this message translates to:
  /// **'Nom du profil'**
  String get nomProfil;

  /// No description provided for @confirmerSuppression.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les données de ce profil seront perdues.'**
  String get confirmerSuppression;

  /// No description provided for @reessayer.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get reessayer;

  /// No description provided for @retour.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get retour;

  /// No description provided for @erreur.
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get erreur;

  /// No description provided for @tout.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get tout;

  /// No description provided for @live.
  ///
  /// In fr, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @vod.
  ///
  /// In fr, this message translates to:
  /// **'VOD'**
  String get vod;

  /// No description provided for @series.
  ///
  /// In fr, this message translates to:
  /// **'Séries'**
  String get series;

  /// No description provided for @serie.
  ///
  /// In fr, this message translates to:
  /// **'Série'**
  String get serie;

  /// No description provided for @changerProfil.
  ///
  /// In fr, this message translates to:
  /// **'Changer de profil'**
  String get changerProfil;

  /// No description provided for @ordreParDefaut.
  ///
  /// In fr, this message translates to:
  /// **'Ordre par défaut'**
  String get ordreParDefaut;

  /// No description provided for @alphabetique.
  ///
  /// In fr, this message translates to:
  /// **'Alphabétique'**
  String get alphabetique;

  /// No description provided for @parNumero.
  ///
  /// In fr, this message translates to:
  /// **'Par numéro'**
  String get parNumero;

  /// No description provided for @vueListe.
  ///
  /// In fr, this message translates to:
  /// **'Vue liste'**
  String get vueListe;

  /// No description provided for @vueGrille.
  ///
  /// In fr, this message translates to:
  /// **'Vue grille'**
  String get vueGrille;

  /// No description provided for @rechercheGlobale.
  ///
  /// In fr, this message translates to:
  /// **'Recherche globale'**
  String get rechercheGlobale;

  /// No description provided for @modeHorsLigne.
  ///
  /// In fr, this message translates to:
  /// **'Mode hors-ligne — Serveur indisponible'**
  String get modeHorsLigne;

  /// No description provided for @recemmentAjoutes.
  ///
  /// In fr, this message translates to:
  /// **'Récemment ajoutés'**
  String get recemmentAjoutes;

  /// No description provided for @raccourciQuitter.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get raccourciQuitter;

  /// No description provided for @raccourciReglages.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get raccourciReglages;

  /// No description provided for @raccourciRechercher.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get raccourciRechercher;

  /// No description provided for @raccourciHistorique.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get raccourciHistorique;

  /// No description provided for @raccourciGuideTV.
  ///
  /// In fr, this message translates to:
  /// **'Guide TV'**
  String get raccourciGuideTV;

  /// No description provided for @raccourciAide.
  ///
  /// In fr, this message translates to:
  /// **'Cette aide'**
  String get raccourciAide;

  /// No description provided for @sectionLecteur.
  ///
  /// In fr, this message translates to:
  /// **'Lecteur'**
  String get sectionLecteur;

  /// No description provided for @lecteurPause.
  ///
  /// In fr, this message translates to:
  /// **'Lecture / Pause'**
  String get lecteurPause;

  /// No description provided for @reculerAvancer.
  ///
  /// In fr, this message translates to:
  /// **'Reculer / Avancer 10s'**
  String get reculerAvancer;

  /// No description provided for @volumePlusMoins.
  ///
  /// In fr, this message translates to:
  /// **'Volume +/−'**
  String get volumePlusMoins;

  /// No description provided for @pleinEcran.
  ///
  /// In fr, this message translates to:
  /// **'Plein écran'**
  String get pleinEcran;

  /// No description provided for @couperSon.
  ///
  /// In fr, this message translates to:
  /// **'Couper le son'**
  String get couperSon;

  /// No description provided for @quitterLecteur.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le lecteur'**
  String get quitterLecteur;

  /// No description provided for @chainePrecSuiv.
  ///
  /// In fr, this message translates to:
  /// **'Chaîne précédente / suivante'**
  String get chainePrecSuiv;

  /// No description provided for @films.
  ///
  /// In fr, this message translates to:
  /// **'Films'**
  String get films;

  /// No description provided for @nonVus.
  ///
  /// In fr, this message translates to:
  /// **'Non vus'**
  String get nonVus;

  /// No description provided for @enCoursFiltre.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get enCoursFiltre;

  /// No description provided for @ilYaMinutes.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} min'**
  String ilYaMinutes(int count);

  /// No description provided for @ilYaHeures.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count}h'**
  String ilYaHeures(int count);

  /// No description provided for @hier.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get hier;

  /// No description provided for @ilYaJours.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} jours'**
  String ilYaJours(int count);

  /// No description provided for @quitterPleinEcran.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le plein écran'**
  String get quitterPleinEcran;

  /// No description provided for @desentrelacement.
  ///
  /// In fr, this message translates to:
  /// **'Désentrelacement'**
  String get desentrelacement;

  /// No description provided for @miniPlayer.
  ///
  /// In fr, this message translates to:
  /// **'Mini-player'**
  String get miniPlayer;

  /// No description provided for @lireMaintenant.
  ///
  /// In fr, this message translates to:
  /// **'Lire maintenant ({seconds})'**
  String lireMaintenant(int seconds);

  /// No description provided for @veilleActive.
  ///
  /// In fr, this message translates to:
  /// **'Veille dans {minutes} min'**
  String veilleActive(int minutes);

  /// No description provided for @minuterieEcoulee.
  ///
  /// In fr, this message translates to:
  /// **'Minuterie écoulée — lecture en pause'**
  String get minuterieEcoulee;

  /// No description provided for @annulerMinuterie.
  ///
  /// In fr, this message translates to:
  /// **'Annuler ({minutes} min restantes)'**
  String annulerMinuterie(int minutes);

  /// No description provided for @xMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{count} minutes'**
  String xMinutes(int count);

  /// No description provided for @audioTab.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get audioTab;

  /// No description provided for @sousTitresTab.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres'**
  String get sousTitresTab;

  /// No description provided for @pisteAudio.
  ///
  /// In fr, this message translates to:
  /// **'Piste audio'**
  String get pisteAudio;

  /// No description provided for @desactiverSousTitres.
  ///
  /// In fr, this message translates to:
  /// **'Désactivés'**
  String get desactiverSousTitres;

  /// No description provided for @blanc.
  ///
  /// In fr, this message translates to:
  /// **'Blanc'**
  String get blanc;

  /// No description provided for @jaune.
  ///
  /// In fr, this message translates to:
  /// **'Jaune'**
  String get jaune;

  /// No description provided for @vert.
  ///
  /// In fr, this message translates to:
  /// **'Vert'**
  String get vert;

  /// No description provided for @cyan.
  ///
  /// In fr, this message translates to:
  /// **'Cyan'**
  String get cyan;

  /// No description provided for @taille.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get taille;

  /// No description provided for @couleurLabel.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get couleurLabel;

  /// No description provided for @fondLabel.
  ///
  /// In fr, this message translates to:
  /// **'Fond'**
  String get fondLabel;

  /// No description provided for @chargementEpg.
  ///
  /// In fr, this message translates to:
  /// **'Chargement EPG {loaded}/{total}'**
  String chargementEpg(int loaded, int total);

  /// No description provided for @demain.
  ///
  /// In fr, this message translates to:
  /// **'Demain'**
  String get demain;

  /// No description provided for @nombreChaines.
  ///
  /// In fr, this message translates to:
  /// **'{count} chaîne(s)'**
  String nombreChaines(int count);

  /// No description provided for @passe.
  ///
  /// In fr, this message translates to:
  /// **'passé'**
  String get passe;

  /// No description provided for @enCoursProg.
  ///
  /// In fr, this message translates to:
  /// **'EN COURS'**
  String get enCoursProg;

  /// No description provided for @revoir.
  ///
  /// In fr, this message translates to:
  /// **'Revoir'**
  String get revoir;

  /// No description provided for @replay.
  ///
  /// In fr, this message translates to:
  /// **'REPLAY'**
  String get replay;

  /// No description provided for @programmeCours.
  ///
  /// In fr, this message translates to:
  /// **'Programme en cours :'**
  String get programmeCours;

  /// No description provided for @epgIndisponible.
  ///
  /// In fr, this message translates to:
  /// **'EPG indisponible'**
  String get epgIndisponible;

  /// No description provided for @gererProfilsBouton.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les profils'**
  String get gererProfilsBouton;

  /// No description provided for @sauvegarderConfigBtn.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder'**
  String get sauvegarderConfigBtn;

  /// No description provided for @restaurerConfigBtn.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get restaurerConfigBtn;

  /// No description provided for @langueAudioPreferee.
  ///
  /// In fr, this message translates to:
  /// **'Langue audio préférée'**
  String get langueAudioPreferee;

  /// No description provided for @langueSousTitresPreferee.
  ///
  /// In fr, this message translates to:
  /// **'Langue sous-titres préférée'**
  String get langueSousTitresPreferee;

  /// No description provided for @cacheEpgEntrees.
  ///
  /// In fr, this message translates to:
  /// **'Cache EPG : {count} entrées'**
  String cacheEpgEntrees(int count);

  /// No description provided for @viderCacheEpg.
  ///
  /// In fr, this message translates to:
  /// **'Vider le cache EPG'**
  String get viderCacheEpg;

  /// No description provided for @viderCacheImages.
  ///
  /// In fr, this message translates to:
  /// **'Vider le cache images'**
  String get viderCacheImages;

  /// No description provided for @descriptionCache.
  ///
  /// In fr, this message translates to:
  /// **'Le cache EPG stocke les programmes TV pour un accès rapide. Le cache images stocke les affiches et logos téléchargés.'**
  String get descriptionCache;

  /// No description provided for @configSauvegardeeVers.
  ///
  /// In fr, this message translates to:
  /// **'Configuration sauvegardée → {path}'**
  String configSauvegardeeVers(String path);

  /// No description provided for @configRestauree.
  ///
  /// In fr, this message translates to:
  /// **'Configuration restaurée. Redémarrage...'**
  String get configRestauree;

  /// No description provided for @erreurImport.
  ///
  /// In fr, this message translates to:
  /// **'Erreur import : {detail}'**
  String erreurImport(String detail);

  /// No description provided for @erreurExport.
  ///
  /// In fr, this message translates to:
  /// **'Erreur export : {detail}'**
  String erreurExport(String detail);

  /// No description provided for @erreurSauvegarde.
  ///
  /// In fr, this message translates to:
  /// **'Erreur sauvegarde : {detail}'**
  String erreurSauvegarde(String detail);

  /// No description provided for @erreurRestauration.
  ///
  /// In fr, this message translates to:
  /// **'Erreur restauration : {detail}'**
  String erreurRestauration(String detail);

  /// No description provided for @entreesImporteesMu3.
  ///
  /// In fr, this message translates to:
  /// **'{count} entrées importées depuis M3U'**
  String entreesImporteesMu3(int count);

  /// No description provided for @favorisExportesVers.
  ///
  /// In fr, this message translates to:
  /// **'Favoris exportés → {path}'**
  String favorisExportesVers(String path);

  /// No description provided for @profilDonneesSupprimees.
  ///
  /// In fr, this message translates to:
  /// **'Le profil \"{name}\" et ses données seront supprimés.'**
  String profilDonneesSupprimees(String name);

  /// No description provided for @normaleVitesse.
  ///
  /// In fr, this message translates to:
  /// **'Normale (1×)'**
  String get normaleVitesse;

  /// No description provided for @etirer.
  ///
  /// In fr, this message translates to:
  /// **'Étirer'**
  String get etirer;

  /// No description provided for @aRegarder.
  ///
  /// In fr, this message translates to:
  /// **'À regarder'**
  String get aRegarder;

  /// No description provided for @collectionsSection.
  ///
  /// In fr, this message translates to:
  /// **'COLLECTIONS'**
  String get collectionsSection;

  /// No description provided for @nomLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get nomLabel;

  /// No description provided for @nomCollection.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la collection'**
  String get nomCollection;

  /// No description provided for @collectionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Collection'**
  String get collectionLabel;

  /// No description provided for @retirerCollection.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la collection'**
  String get retirerCollection;

  /// No description provided for @aRegarderPlusTard.
  ///
  /// In fr, this message translates to:
  /// **'À regarder plus tard'**
  String get aRegarderPlusTard;

  /// No description provided for @xSelectionnes.
  ///
  /// In fr, this message translates to:
  /// **'{count} sélectionné(s)'**
  String xSelectionnes(int count);

  /// No description provided for @ajouteACollection.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté à \"{name}\"'**
  String ajouteACollection(String name);

  /// No description provided for @collectionCreeAvec.
  ///
  /// In fr, this message translates to:
  /// **'Collection \"{name}\" créée avec {count} éléments'**
  String collectionCreeAvec(String name, int count);

  /// No description provided for @nouvelleCollectionAvec.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle collection ({count} éléments)'**
  String nouvelleCollectionAvec(int count);

  /// No description provided for @saisons.
  ///
  /// In fr, this message translates to:
  /// **'Saisons'**
  String get saisons;

  /// No description provided for @saison.
  ///
  /// In fr, this message translates to:
  /// **'Saison {number}'**
  String saison(String number);

  /// No description provided for @vu.
  ///
  /// In fr, this message translates to:
  /// **'Vu'**
  String get vu;

  /// No description provided for @serveurConfigure.
  ///
  /// In fr, this message translates to:
  /// **'Votre serveur est configuré !'**
  String get serveurConfigure;

  /// No description provided for @categorie.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie : {name}'**
  String categorie(String name);

  /// No description provided for @note.
  ///
  /// In fr, this message translates to:
  /// **'Note : {value}'**
  String note(String value);

  /// No description provided for @nbSaisons.
  ///
  /// In fr, this message translates to:
  /// **'Saisons : {count}'**
  String nbSaisons(String count);

  /// No description provided for @typeStream.
  ///
  /// In fr, this message translates to:
  /// **'Type : {type}'**
  String typeStream(String type);

  /// No description provided for @reprendreDepuis.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre à {time}'**
  String reprendreDepuis(String time);

  /// No description provided for @continuerOuDebut.
  ///
  /// In fr, this message translates to:
  /// **'Continuer depuis {time} ou repartir depuis le début ?'**
  String continuerOuDebut(String time);

  /// No description provided for @suivantEpg.
  ///
  /// In fr, this message translates to:
  /// **'Suivant : {title}'**
  String suivantEpg(String title);

  /// No description provided for @confirmerSupprimerCollection.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette collection ?'**
  String get confirmerSupprimerCollection;

  /// No description provided for @confirmerRetirerCollection.
  ///
  /// In fr, this message translates to:
  /// **'Retirer cet élément de la collection ?'**
  String get confirmerRetirerCollection;

  /// No description provided for @confirmerViderCache.
  ///
  /// In fr, this message translates to:
  /// **'Vider le cache EPG ?'**
  String get confirmerViderCache;

  /// No description provided for @listeChaines.
  ///
  /// In fr, this message translates to:
  /// **'Liste des chaînes'**
  String get listeChaines;

  /// No description provided for @numeroChaineDirecte.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de chaîne direct'**
  String get numeroChaineDirecte;

  /// No description provided for @splashLoadingConfig.
  ///
  /// In fr, this message translates to:
  /// **'Chargement de la configuration…'**
  String get splashLoadingConfig;

  /// No description provided for @splashConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion au serveur…'**
  String get splashConnecting;

  /// No description provided for @splashReady.
  ///
  /// In fr, this message translates to:
  /// **'Prêt !'**
  String get splashReady;

  /// No description provided for @entrerPinParental.
  ///
  /// In fr, this message translates to:
  /// **'Entrer le PIN parental'**
  String get entrerPinParental;

  /// No description provided for @pinIncorrectReessayer.
  ///
  /// In fr, this message translates to:
  /// **'PIN incorrect — réessayer'**
  String get pinIncorrectReessayer;

  /// No description provided for @choisirPin.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un PIN (4 chiffres)'**
  String get choisirPin;

  /// No description provided for @confirmerPin.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le PIN'**
  String get confirmerPin;

  /// No description provided for @pinsNeCorrespondentPas.
  ///
  /// In fr, this message translates to:
  /// **'Les PINs ne correspondent pas'**
  String get pinsNeCorrespondentPas;

  /// No description provided for @pinActuel.
  ///
  /// In fr, this message translates to:
  /// **'PIN actuel'**
  String get pinActuel;

  /// No description provided for @pinIncorrect.
  ///
  /// In fr, this message translates to:
  /// **'PIN incorrect'**
  String get pinIncorrect;

  /// No description provided for @nouveauPin.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau PIN (4 chiffres)'**
  String get nouveauPin;

  /// No description provided for @confirmerNouveauPin.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le nouveau PIN'**
  String get confirmerNouveauPin;

  /// No description provided for @pinModifie.
  ///
  /// In fr, this message translates to:
  /// **'PIN modifié'**
  String get pinModifie;

  /// No description provided for @supprimerControleParentalQ.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le contrôle parental ?'**
  String get supprimerControleParentalQ;

  /// No description provided for @pinEtCategoriesSupprimees.
  ///
  /// In fr, this message translates to:
  /// **'Le PIN et toutes les catégories bloquées seront supprimés.'**
  String get pinEtCategoriesSupprimees;

  /// No description provided for @controleParental.
  ///
  /// In fr, this message translates to:
  /// **'Contrôle parental'**
  String get controleParental;

  /// No description provided for @descriptionControleParental.
  ///
  /// In fr, this message translates to:
  /// **'Le contrôle parental permet de masquer certaines catégories\nderrière un code PIN.'**
  String get descriptionControleParental;

  /// No description provided for @activerControleParental.
  ///
  /// In fr, this message translates to:
  /// **'Activer le contrôle parental'**
  String get activerControleParental;

  /// No description provided for @entrerPinAcceder.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre PIN pour accéder aux paramètres parentaux.'**
  String get entrerPinAcceder;

  /// No description provided for @entrerLePin.
  ///
  /// In fr, this message translates to:
  /// **'Entrer le PIN'**
  String get entrerLePin;

  /// No description provided for @changerLePin.
  ///
  /// In fr, this message translates to:
  /// **'Changer le PIN'**
  String get changerLePin;

  /// No description provided for @desactiverParental.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver'**
  String get desactiverParental;

  /// No description provided for @categoriesBloquees.
  ///
  /// In fr, this message translates to:
  /// **'CATÉGORIES BLOQUÉES'**
  String get categoriesBloquees;

  /// No description provided for @categoriesMasquees.
  ///
  /// In fr, this message translates to:
  /// **'Les catégories cochées seront masquées tant que le contrôle parental est verrouillé.'**
  String get categoriesMasquees;

  /// No description provided for @tvEnDirect.
  ///
  /// In fr, this message translates to:
  /// **'TV en direct'**
  String get tvEnDirect;

  /// No description provided for @filmsVod.
  ///
  /// In fr, this message translates to:
  /// **'Films (VOD)'**
  String get filmsVod;

  /// No description provided for @catchupNonDisponible.
  ///
  /// In fr, this message translates to:
  /// **'Catch-up non disponible pour ce programme.\nLe serveur ne supporte peut-être pas le timeshift.'**
  String get catchupNonDisponible;

  /// No description provided for @impossibleLireFlux.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire ce flux.\nVérifiez votre connexion ou réessayez.'**
  String get impossibleLireFlux;

  /// No description provided for @connexionRetablie.
  ///
  /// In fr, this message translates to:
  /// **'Connexion rétablie'**
  String get connexionRetablie;

  /// No description provided for @cliquerPourRevoir.
  ///
  /// In fr, this message translates to:
  /// **'Cliquer pour revoir (Catch-up)'**
  String get cliquerPourRevoir;

  /// No description provided for @programmesRecents.
  ///
  /// In fr, this message translates to:
  /// **'Replay disponible'**
  String get programmesRecents;

  /// No description provided for @ilYA.
  ///
  /// In fr, this message translates to:
  /// **'il y a {time}'**
  String ilYA(String time);

  /// No description provided for @toutEffacer.
  ///
  /// In fr, this message translates to:
  /// **'Tout effacer'**
  String get toutEffacer;

  /// No description provided for @chiffre.
  ///
  /// In fr, this message translates to:
  /// **'Chiffre {number}'**
  String chiffre(String number);

  /// No description provided for @rechercherCategorie.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une catégorie…'**
  String get rechercherCategorie;

  /// No description provided for @chainesTV.
  ///
  /// In fr, this message translates to:
  /// **'Chaînes TV'**
  String get chainesTV;

  /// No description provided for @nCategoriesBloqueesLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune catégorie bloquée} =1{1 catégorie bloquée} other{{count} catégories bloquées}}'**
  String nCategoriesBloqueesLabel(int count);

  /// No description provided for @quiRegarde.
  ///
  /// In fr, this message translates to:
  /// **'Qui regarde ?'**
  String get quiRegarde;

  /// No description provided for @entrerPinProfil.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le PIN du profil'**
  String get entrerPinProfil;

  /// No description provided for @avatarProfil.
  ///
  /// In fr, this message translates to:
  /// **'Avatar'**
  String get avatarProfil;

  /// No description provided for @pinProfil.
  ///
  /// In fr, this message translates to:
  /// **'PIN du profil (optionnel)'**
  String get pinProfil;

  /// No description provided for @pinProfilDesc.
  ///
  /// In fr, this message translates to:
  /// **'Protéger ce profil par un code PIN à 4 chiffres'**
  String get pinProfilDesc;

  /// No description provided for @definirPin.
  ///
  /// In fr, this message translates to:
  /// **'Définir un PIN'**
  String get definirPin;

  /// No description provided for @supprimerPin.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le PIN'**
  String get supprimerPin;

  /// No description provided for @programmesTV.
  ///
  /// In fr, this message translates to:
  /// **'Programmes'**
  String get programmesTV;

  /// No description provided for @rechercheRecente.
  ///
  /// In fr, this message translates to:
  /// **'Recherches récentes'**
  String get rechercheRecente;

  /// No description provided for @effacerRecherches.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get effacerRecherches;

  /// No description provided for @nResultats.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun résultat} =1{1 résultat} other{{count} résultats}}'**
  String nResultats(int count);

  /// No description provided for @pinDefini.
  ///
  /// In fr, this message translates to:
  /// **'PIN défini'**
  String get pinDefini;

  /// No description provided for @meRappeler.
  ///
  /// In fr, this message translates to:
  /// **'Me rappeler'**
  String get meRappeler;

  /// No description provided for @rappelActif.
  ///
  /// In fr, this message translates to:
  /// **'Rappel actif'**
  String get rappelActif;

  /// No description provided for @rappelProgramme.
  ///
  /// In fr, this message translates to:
  /// **'{title} commence bientôt sur {channel}'**
  String rappelProgramme(String title, String channel);

  /// No description provided for @chiffresSaisis.
  ///
  /// In fr, this message translates to:
  /// **'{count} chiffres sur {total} saisis'**
  String chiffresSaisis(int count, int total);

  /// No description provided for @aVenir.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get aVenir;

  /// No description provided for @detailChaine.
  ///
  /// In fr, this message translates to:
  /// **'Détail de la chaîne'**
  String get detailChaine;

  /// No description provided for @lire.
  ///
  /// In fr, this message translates to:
  /// **'Lire'**
  String get lire;

  /// No description provided for @reprendre.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre ({time})'**
  String reprendre(String time);

  /// No description provided for @pasDeSynopsis.
  ///
  /// In fr, this message translates to:
  /// **'Aucun synopsis disponible.'**
  String get pasDeSynopsis;

  /// No description provided for @detailVod.
  ///
  /// In fr, this message translates to:
  /// **'Détail'**
  String get detailVod;

  /// No description provided for @importerM3u.
  ///
  /// In fr, this message translates to:
  /// **'Importer un fichier M3U'**
  String get importerM3u;

  /// No description provided for @testerConnexion.
  ///
  /// In fr, this message translates to:
  /// **'Tester la connexion'**
  String get testerConnexion;

  /// No description provided for @connexionReussie.
  ///
  /// In fr, this message translates to:
  /// **'Connexion réussie !'**
  String get connexionReussie;

  /// No description provided for @fichierM3uInvalide.
  ///
  /// In fr, this message translates to:
  /// **'Fichier M3U invalide ou non reconnu.'**
  String get fichierM3uInvalide;

  /// No description provided for @importReussi.
  ///
  /// In fr, this message translates to:
  /// **'Identifiants importés avec succès !'**
  String get importReussi;

  /// No description provided for @reglagesAvances.
  ///
  /// In fr, this message translates to:
  /// **'RÉGLAGES AVANCÉS'**
  String get reglagesAvances;

  /// No description provided for @tentativesMax.
  ///
  /// In fr, this message translates to:
  /// **'Tentatives max'**
  String get tentativesMax;

  /// No description provided for @delaiConnexion.
  ///
  /// In fr, this message translates to:
  /// **'Délai de connexion (sec)'**
  String get delaiConnexion;

  /// No description provided for @descriptionAvances.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres de connexion au serveur.'**
  String get descriptionAvances;

  /// No description provided for @marquerVu.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme vu'**
  String get marquerVu;

  /// No description provided for @marquerNonVu.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme non vu'**
  String get marquerNonVu;

  /// No description provided for @episodesMarquesVus.
  ///
  /// In fr, this message translates to:
  /// **'{count} épisodes marqués comme vus'**
  String episodesMarquesVus(int count);

  /// No description provided for @notifRappelEpg.
  ///
  /// In fr, this message translates to:
  /// **'Rappel EPG'**
  String get notifRappelEpg;

  /// No description provided for @notifBientot.
  ///
  /// In fr, this message translates to:
  /// **'{title} commence bientôt sur {channel}'**
  String notifBientot(String title, String channel);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
