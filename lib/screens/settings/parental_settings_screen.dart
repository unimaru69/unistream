import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
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
    final pin = await showPinDialog(context, title: 'Entrer le PIN parental');
    if (pin == null) return;
    final ok = await ref.read(parentalProvider.notifier).verifyAndUnlock(pin);
    if (ok) {
      setState(() => _authenticated = true);
    } else {
      if (!mounted) return;
      // Show error and retry
      final retry =
          await showPinDialog(context, title: 'PIN incorrect — r\u00e9essayer');
      if (retry == null) return;
      final ok2 =
          await ref.read(parentalProvider.notifier).verifyAndUnlock(retry);
      if (ok2 && mounted) {
        setState(() => _authenticated = true);
      }
    }
  }

  Future<void> _setPin() async {
    final pin = await showPinDialog(context, title: 'Choisir un PIN (4 chiffres)');
    if (pin == null) return;
    // Confirm
    if (!mounted) return;
    final confirm =
        await showPinDialog(context, title: 'Confirmer le PIN');
    if (confirm == null) return;
    if (pin != confirm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Les PINs ne correspondent pas'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    await ref.read(parentalProvider.notifier).setPin(pin);
    setState(() => _authenticated = true);
  }

  Future<void> _changePin() async {
    // Verify current PIN first
    final current =
        await showPinDialog(context, title: 'PIN actuel');
    if (current == null) return;
    final ok = await ref.read(parentalProvider.notifier).verifyAndUnlock(current);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('PIN incorrect'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (!mounted) return;
    final newPin =
        await showPinDialog(context, title: 'Nouveau PIN (4 chiffres)');
    if (newPin == null) return;
    if (!mounted) return;
    final confirm =
        await showPinDialog(context, title: 'Confirmer le nouveau PIN');
    if (confirm == null || confirm != newPin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Les PINs ne correspondent pas'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    await ref.read(parentalProvider.notifier).setPin(newPin);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN modifi\u00e9')),
    );
  }

  Future<void> _clearPin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Supprimer le contr\u00f4le parental ?',
            style: TextStyle(fontSize: 16)),
        content: const Text(
            'Le PIN et toutes les cat\u00e9gories bloqu\u00e9es seront supprim\u00e9s.',
            style: TextStyle(fontSize: 14, color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(parentalProvider.notifier).clearPin();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final parental = ref.watch(parentalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contr\u00f4le parental'),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline, size: 64, color: Colors.white24),
        const SizedBox(height: 16),
        const Text(
          'Le contr\u00f4le parental permet de masquer certaines cat\u00e9gories\nderri\u00e8re un code PIN.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white54),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _setPin,
          icon: const Icon(Icons.lock, size: 18),
          label: const Text('Activer le contr\u00f4le parental'),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock, size: 64, color: Colors.white24),
        const SizedBox(height: 16),
        const Text(
          'Entrez votre PIN pour acc\u00e9der aux param\u00e8tres parentaux.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white54),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _authenticate,
          icon: const Icon(Icons.vpn_key, size: 18),
          label: const Text('Entrer le PIN'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Actions
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _changePin,
              icon: const Icon(Icons.vpn_key, size: 18),
              label: const Text('Changer le PIN'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
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
              label: const Text('D\u00e9sactiver'),
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
        const Divider(color: Colors.white12),
        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'CAT\u00c9GORIES BLOQU\u00c9ES',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white38,
                letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Les cat\u00e9gories coch\u00e9es seront masqu\u00e9es tant que le contr\u00f4le parental est verrouill\u00e9.',
          style: TextStyle(fontSize: 12, color: Colors.white38),
        ),
        const SizedBox(height: 16),
        if (_loadingCategories)
          const Center(child: CircularProgressIndicator())
        else ...[
          _buildCategorySection('TV en direct', _liveCategories, parental),
          _buildCategorySection('Films (VOD)', _vodCategories, parental),
          _buildCategorySection('S\u00e9ries', _seriesCategories, parental),
        ],
      ],
    );
  }

  Widget _buildCategorySection(
      String title, List<cat.Category> categories, ParentalState parental) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70)),
        ),
        ...categories.map((c) {
          final blocked = parental.blockedCategoryIds.contains(c.categoryId);
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(c.categoryName,
                style: const TextStyle(fontSize: 13, color: Colors.white)),
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
