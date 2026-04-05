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
///   - Change PIN / Clear PIN
///   - Tabbed category list (Live / VOD / Series) with search
class ParentalSettingsScreen extends ConsumerStatefulWidget {
  const ParentalSettingsScreen({super.key});

  @override
  ConsumerState<ParentalSettingsScreen> createState() =>
      _ParentalSettingsScreenState();
}

class _ParentalSettingsScreenState
    extends ConsumerState<ParentalSettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _authenticated = false;
  List<cat.Category> _liveCategories = [];
  List<cat.Category> _vodCategories = [];
  List<cat.Category> _seriesCategories = [];
  bool _loadingCategories = true;
  String _search = '';
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    final parental = ref.read(parentalProvider);
    if (!parental.isEnabled) {
      _authenticated = true;
    }
    _loadAllCategories();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  /// Lock parental controls when navigating back, so blocked categories
  /// are filtered on the home screen.
  void _lockAndPop() {
    ref.read(parentalProvider.notifier).lock();
    Navigator.of(context).pop();
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
    if (!mounted) return;
    final confirm = await showPinDialog(context, title: l10n.confirmerPin);
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
    try {
      await ref.read(parentalProvider.notifier).setPin(pin);
      if (mounted) setState(() => _authenticated = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _changePin() async {
    final l10n = AppLocalizations.of(context)!;
    final current = await showPinDialog(context, title: l10n.pinActuel);
    if (current == null) return;
    final ok =
        await ref.read(parentalProvider.notifier).verifyAndUnlock(current);
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
    final newPin = await showPinDialog(context, title: l10n.nouveauPin);
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
          content: Text(l10n.pinEtCategoriesSupprimees,
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _lockAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _lockAndPop,
          ),
          title: Text(l10n.controleParental),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: !parental.isEnabled
            ? Center(child: _buildSetPinView())
            : !_authenticated
                ? Center(child: _buildLockedView())
                : _buildSettingsView(parental),
      ),
    );
  }

  Widget _buildSetPinView() {
    final tc = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedView() {
    final tc = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsView(ParentalState parental) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final blockedCount = parental.blockedCategoryIds.length;

    return Column(children: [
      // ── Header: actions + search ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Action buttons
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _changePin,
                  icon: const Icon(Icons.vpn_key, size: 18),
                  label: Text(l10n.changerLePin),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tc.textSecondary,
                    side: BorderSide(color: tc.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                  label: Text(l10n.desactiverParental),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            // Blocked count chip
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(Icons.block, size: 16,
                    color: blockedCount > 0 ? Colors.redAccent : tc.textDisabled),
                label: Text(l10n.nCategoriesBloqueesLabel(blockedCount),
                    style: TextStyle(fontSize: 12, color: tc.textSecondary)),
                backgroundColor: tc.inputFill,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 8),
            // Search field
            TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              style: TextStyle(fontSize: 14, color: tc.textPrimary),
              decoration: InputDecoration(
                hintText: l10n.rechercherCategorie,
                hintStyle: TextStyle(color: tc.textDisabled, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: tc.textDisabled, size: 20),
                filled: true,
                fillColor: tc.inputFill,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      // ── Tabs ──
      TabBar(
        controller: _tabCtrl,
        labelColor: AppColors.primaryBlue,
        unselectedLabelColor: tc.textTertiary,
        indicatorColor: AppColors.primaryBlue,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: [
          Tab(text: l10n.chainesTV),
          Tab(text: l10n.filmsVod),
          Tab(text: l10n.series),
        ],
      ),
      // ── Category list ──
      Expanded(
        child: _loadingCategories
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildCategoryList(_liveCategories, parental),
                  _buildCategoryList(_vodCategories, parental),
                  _buildCategoryList(_seriesCategories, parental),
                ],
              ),
      ),
    ]);
  }

  Widget _buildCategoryList(
      List<cat.Category> categories, ParentalState parental) {
    final tc = AppThemeColors.of(context);
    final filtered = _search.isEmpty
        ? categories
        : categories
            .where((c) =>
                c.categoryName.toLowerCase().contains(_search))
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _search.isEmpty
              ? AppLocalizations.of(context)!.aucunResultat
              : AppLocalizations.of(context)!.aucunResultat,
          style: TextStyle(color: tc.textDisabled, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final c = filtered[i];
        final blocked = parental.blockedCategoryIds.contains(c.categoryId);
        return CheckboxListTile(
          dense: true,
          title: Text(c.categoryName,
              style: TextStyle(
                fontSize: 13,
                color: blocked ? Colors.redAccent : tc.textPrimary,
                fontWeight: blocked ? FontWeight.w600 : FontWeight.normal,
              )),
          secondary: blocked
              ? const Icon(Icons.block, color: Colors.redAccent, size: 18)
              : null,
          value: blocked,
          activeColor: Colors.redAccent,
          onChanged: (_) =>
              ref.read(parentalProvider.notifier).toggleCategory(c.categoryId),
        );
      },
    );
  }
}
