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
