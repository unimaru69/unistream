// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get annuler => 'Cancel';

  @override
  String get fermer => 'Close';

  @override
  String get supprimer => 'Delete';

  @override
  String get enregistrer => 'Save';

  @override
  String get creer => 'Create';

  @override
  String get connexion => 'Sign in';

  @override
  String get effacer => 'Clear';

  @override
  String get oui => 'Yes';

  @override
  String get non => 'No';

  @override
  String get favoris => 'Favorites';

  @override
  String get historique => 'History';

  @override
  String get parametres => 'Settings';

  @override
  String get rechercher => 'Search';

  @override
  String get guideTV => 'TV Guide';

  @override
  String get profils => 'Profiles';

  @override
  String get rechercherCatalogue => 'Search entire catalog…';

  @override
  String get rechercherDots => 'Search...';

  @override
  String get aucunResultat => 'No results';

  @override
  String get tapeAuMoins2 => 'Type at least 2 characters';

  @override
  String get aucunHistorique => 'No history';

  @override
  String get aucunProgramme => 'No program';

  @override
  String get selectionneCategorie => 'Select a category';

  @override
  String get selectionneSaison => 'Select a season';

  @override
  String get aucuneDonneesCache => 'No cached data available';

  @override
  String get connexionRequise => 'Connection required';

  @override
  String get reprendreLecture => 'Resume playback?';

  @override
  String get depuisDebut => 'From the beginning';

  @override
  String get episodeSuivant => 'Next episode';

  @override
  String get vitesseLecture => 'Playback speed';

  @override
  String get ratioAspect => 'Aspect ratio';

  @override
  String get minuterieVeille => 'Sleep timer';

  @override
  String get styleSousTitres => 'Subtitle style';

  @override
  String get nouvelleCollection => 'New collection';

  @override
  String get creerCollection => 'Create collection';

  @override
  String get ajouterCollection => 'Add to a collection';

  @override
  String get nouveauProfil => 'New profile';

  @override
  String get modifierProfil => 'Edit profile';

  @override
  String get supprimerProfil => 'Delete this profile?';

  @override
  String get ajouterProfil => 'Add a profile';

  @override
  String get testerEtAjouter => 'Test and add';

  @override
  String get tousChampRequis => 'All fields are required';

  @override
  String get authEchouee => 'Authentication failed';

  @override
  String get importExport => 'IMPORT / EXPORT';

  @override
  String get apparence => 'APPEARANCE';

  @override
  String get langues => 'LANGUAGES';

  @override
  String get cacheSection => 'CACHE';

  @override
  String get effacerHistorique => 'Clear history';

  @override
  String get effacerHistoireQuestion => 'Clear history?';

  @override
  String get actionIrreversible => 'This action cannot be undone.';

  @override
  String get entreeSupprimee => 'Entry deleted';

  @override
  String get sansTitre => 'Untitled';

  @override
  String get raccourcisClavier => 'Keyboard shortcuts';

  @override
  String get continuerRegarder => 'Continue watching';

  @override
  String get favorisPremier => 'Favorites first';

  @override
  String get trier => 'Sort';

  @override
  String get filtrerChaines => 'Filter channels...';

  @override
  String get annulerSelection => 'Cancel selection';

  @override
  String get selectionnerPourCollection => 'Select to create a collection';

  @override
  String get configureServeur => 'Configure your IPTV server to get started';

  @override
  String get gererProfils => 'Manage profiles';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUrlHint => 'http://myserver.com:8080';

  @override
  String get nomUtilisateur => 'Username';

  @override
  String get motDePasse => 'Password';

  @override
  String get configSauvegardee => 'Configuration saved';

  @override
  String get importM3U => 'Import M3U';

  @override
  String get exportFavoris => 'Export favorites (.m3u)';

  @override
  String get sauvegarderConfig => 'Save config (JSON)';

  @override
  String get restaurerConfig => 'Restore config (JSON)';

  @override
  String get cacheEpgVide => 'EPG cache cleared';

  @override
  String get cacheImagesVide => 'Image cache cleared';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeSombre => 'Dark';

  @override
  String get themeClair => 'Light';

  @override
  String get themeSysteme => 'System';

  @override
  String get langueAudio => 'Audio language';

  @override
  String get langueSousTitres => 'Subtitle language';

  @override
  String get langueInterface => 'Interface language';

  @override
  String get original => 'Original';

  @override
  String get desactive => 'Disabled';

  @override
  String get activer => 'Enable';

  @override
  String get bienvenue => 'Welcome to UniStream';

  @override
  String get commencer => 'Get started';

  @override
  String get errConnexionImpossible =>
      'Connection failed. Check your internet connection.';

  @override
  String get errServeurNeRepond => 'Server not responding. Try again shortly.';

  @override
  String get errCommunication => 'Communication error with server.';

  @override
  String get errReponseInvalide => 'Invalid server response.';

  @override
  String get errIdentifiants =>
      'Incorrect credentials. Check your username and password.';

  @override
  String get errGenerique => 'An error occurred. Try again.';

  @override
  String entreesImportees(int count) {
    return '$count entries imported';
  }

  @override
  String get profil => 'Profile';

  @override
  String get nomProfil => 'Profile name';

  @override
  String get confirmerSuppression => 'All data for this profile will be lost.';
}
