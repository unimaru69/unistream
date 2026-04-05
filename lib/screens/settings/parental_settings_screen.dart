import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unistream/l10n/app_localizations.dart';
import '../../core/colors.dart';
import '../../core/theme_colors.dart';
import '../../models/category.dart' as cat;
import '../../providers/parental_provider.dart';
import '../../services/xtream_api.dart';
import '../../widgets/pin_dialog.dart';

/// Screen for managing parental control settings.
///
/// If no PIN is set, shows only a "Set PIN" button.
/// If a PIN is set, requires PIN entry to access, then shows:
///   - Change PIN
///   - Clear PIN
///   - Category block toggles
class ParentalSettingsScreen extends ConsumerStatefulWidget {
  const ParentalSettingsScreen({super.key});

  @override
  ConsumerState<ParentalSettingsScreen> createState() =>
      _ParentalSettingsScreenState();
}

class _ParentalSettingsScreenState
    extends ConsumerState<ParentalSettingsScreen> {
  bool _authenticated = false;
  List<cat.Category> _liveCategories = [];
  List<cat.Category> _vodCategories = [];
  List<cat.Category> _seriesCategories = [];
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    final parental = ref.read(parentalProvider);
    // If not enabled, no auth needed (user will set a PIN).
    if (!parental.isEnabled) {
      _authenticated = true;
    }
    _loadAllCategories();
  }

  @override
  void dispose() {
    // Re-lock parental controls when leaving settings so the home screen
    // filters blocked categories again.
    ref.read(parentalProvider.notifier).lock();
    super.dispose();
  }

  Future<void> _loadAllCategories() async {
    try {
      final results = await Future.wait([
        XtreamApi.getLiveCategoriesTyped(),
        XtreamApi.getVodCategoriesTyped(),
        XtreamApi.getSeriesCategoriesTyped(),
      ]);
      if (mounted) {
        setState(() {
          _liveCategories = results[0];
          _vodCategories = results[1];
          _seriesCategories = results[2];
          _loadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _authenticate() async {
    final l10n = AppLocalizations.of(context)!;
    final pin = await showPinDialog(context, title: l10n.entrerPinParental);
    if (pin == null) return;
    final ok = await ref.read(parentalProvider.notifier).verifyAndUnlock(pin);
    if (ok) {
      setState(() => _authenticated = true);
    } else {
      if (!mounted) return;
      // Show error and retry
      final retry =
          await showPinDialog(context, title: l10n.pinIncorrectReessayer);
      if (retry == null) return;
      final ok2 =
          await ref.read(parentalProvider.notifier).verifyAndUnlock(retry);
      if (ok2 && mounted) {
        setState(() => _authenticated = true);
      }
    }
  }

  Future<void> _setPin() async {
    final l10n = AppLocalizations.of(context)!;
    final pin = await showPinDialog(context, title: l10n.choisirPin);
    if (pin == null) return;
    // Confirm
    if (!mounted) return;
    final confirm =
        await showPinDialog(context, title: l10n.confirmerPin);
    if (confirm == null) return;
    if (pin != confirm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.pinsNeCorrespondentPas),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    await ref.read(parentalProvider.notifier).setPin(pin);
    setState(() => _authenticated = true);
  }

  Future<void> _changePin() async {
    // Verify current PIN first
    final l10n = AppLocalizations.of(context)!;
    final current =
        await showPinDialog(context, title: l10n.pinActuel);
    if (current == null) return;
    final ok = await ref.read(parentalProvider.notifier).verifyAndUnlock(current);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.pinIncorrect),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (!mounted) return;
    final newPin =
        await showPinDialog(context, title: l10n.nouveauPin);
    if (newPin == null) return;
    if (!mounted) return;
    final confirm =
        await showPinDialog(context, title: l10n.confirmerNouveauPin);
    if (confirm == null || confirm != newPin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.pinsNeCorrespondentPas),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    await ref.read(parentalProvider.notifier).setPin(newPin);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.pinModifie)),
    );
  }

  Future<void> _clearPin() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final tc = AppThemeColors.of(ctx);
        return AlertDialog(
        backgroundColor: tc.surface,
        title: Text(l10n.supprimerControleParentalQ,
            style: const TextStyle(fontSize: 16)),
        content: Text(
            l10n.pinEtCategoriesSupprimees,
            style: TextStyle(fontSize: 14, color: tc.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.annuler)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.supprimer,
                  style: const TextStyle(color: Colors.redAccent))),
        ],
      );
      },
    );
    if (confirmed != true) return;
    await ref.read(parentalProvider.notifier).clearPin();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final parental = ref.watch(parentalProvider);

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.controleParental),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: !parental.isEnabled
                ? _buildSetPinView()
                : !_authenticated
                    ? _buildLockedView()
                    : _buildSettingsView(parental),
          ),
        ),
      ),
    );
  }

  Widget _buildSetPinView() {
    final tc = AppThemeColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 64, color: tc.borderColor),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)!.descriptionControleParental,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: tc.textTertiary),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _setPin,
          icon: const Icon(Icons.lock, size: 18),
          label: Text(AppLocalizations.of(context)!.activerControleParental),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedView() {
    final tc = AppThemeColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock, size: 64, color: tc.borderColor),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)!.entrerPinAcceder,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: tc.textTertiary),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _authenticate,
          icon: const Icon(Icons.vpn_key, size: 18),
          label: Text(AppLocalizations.of(context)!.entrerLePin),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsView(ParentalState parental) {
    final tc = AppThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Actions
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _changePin,
              icon: const Icon(Icons.vpn_key, size: 18),
              label: Text(AppLocalizations.of(context)!.changerLePin),
              style: OutlinedButton.styleFrom(
                foregroundColor: tc.textSecondary,
                side: BorderSide(color: tc.borderColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _clearPin,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(AppLocalizations.of(context)!.desactiverParental),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        Divider(color: tc.divider),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            AppLocalizations.of(context)!.categoriesBloquees,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: tc.textDisabled,
                letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.categoriesMasquees,
          style: TextStyle(fontSize: 12, color: tc.textDisabled),
        ),
        const SizedBox(height: 16),
        if (_loadingCategories)
          const Center(child: CircularProgressIndicator())
        else ...[
          _buildCategorySection(AppLocalizations.of(context)!.tvEnDirect, _liveCategories, parental),
          _buildCategorySection(AppLocalizations.of(context)!.filmsVod, _vodCategories, parental),
          _buildCategorySection(AppLocalizations.of(context)!.series, _seriesCategories, parental),
        ],
      ],
    );
  }

  Widget _buildCategorySection(
      String title, List<cat.Category> categories, ParentalState parental) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final tc = AppThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tc.textSecondary)),
        ),
        ...categories.map((c) {
          final blocked = parental.blockedCategoryIds.contains(c.categoryId);
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(c.categoryName,
                style: TextStyle(fontSize: 13, color: tc.textPrimary)),
            value: blocked,
            activeColor: Colors.redAccent,
            onChanged: (_) =>
                ref.read(parentalProvider.notifier).toggleCategory(c.categoryId),
          );
        }),
      ],
    );
  }
}
