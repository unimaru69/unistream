import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/purchase_provider.dart';
import 'widgets/feature_comparison.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isAnnual = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(purchaseProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paywallTitre),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header gradient
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        l10n.paywallTitre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.paywallDescription,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Feature comparison header
                Row(
                  children: [
                    const Expanded(flex: 3, child: SizedBox()),
                    SizedBox(
                      width: 60,
                      child: Center(
                        child: Text(
                          l10n.abonnementBasic,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white54 : AppColors.lightTextTertiary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Center(
                        child: Text(
                          l10n.abonnementPremium,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const FeatureComparison(),

                const SizedBox(height: 32),

                // Billing period toggle
                _BillingToggle(
                  isAnnual: _isAnnual,
                  onChanged: (v) => setState(() => _isAnnual = v),
                  l10n: l10n,
                ),

                const SizedBox(height: 16),

                // Package buttons
                if (state.offerings != null)
                  _PackageButtons(
                    offerings: state.offerings!,
                    isAnnual: _isAnnual,
                    l10n: l10n,
                    onPurchase: _onPurchase,
                  ),

                if (!state.isAvailable)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      l10n.paywallNonDisponible,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white38 : AppColors.lightTextTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Restore purchases
                TextButton(
                  onPressed: state.isLoading ? null : _onRestore,
                  child: Text(l10n.paywallRestaurer),
                ),

                // Error
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),

          // Loading overlay
          if (state.isLoading)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _onPurchase(Package package) async {
    final l10n = AppLocalizations.of(context)!;
    final success = await ref.read(purchaseProvider.notifier).purchase(package);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.paywallAchatReussi)),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _onRestore() async {
    final l10n = AppLocalizations.of(context)!;
    final success = await ref.read(purchaseProvider.notifier).restore();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? l10n.paywallAchatReussi
              : l10n.paywallAchatErreur),
        ),
      );
      if (success) Navigator.pop(context);
    }
  }
}

class _BillingToggle extends StatelessWidget {
  final bool isAnnual;
  final ValueChanged<bool> onChanged;
  final AppLocalizations l10n;

  const _BillingToggle({
    required this.isAnnual,
    required this.onChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ToggleChip(
          label: l10n.paywallMensuel,
          selected: !isAnnual,
          onTap: () => onChanged(false),
        ),
        const SizedBox(width: 8),
        _ToggleChip(
          label: l10n.paywallAnnuel,
          selected: isAnnual,
          badge: l10n.paywallEconomie(17),
          onTap: () => onChanged(true),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBlue
              : AppColors.primaryBlue.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PackageButtons extends StatelessWidget {
  final Offerings offerings;
  final bool isAnnual;
  final AppLocalizations l10n;
  final Future<void> Function(Package) onPurchase;

  const _PackageButtons({
    required this.offerings,
    required this.isAnnual,
    required this.l10n,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final current = offerings.current;
    if (current == null) return const SizedBox.shrink();

    // Find the right packages based on billing period
    final packages = current.availablePackages.where((p) {
      final id = p.storeProduct.identifier;
      if (isAnnual) {
        return id.contains('annual');
      } else {
        return id.contains('monthly');
      }
    }).toList();

    if (packages.isEmpty) return const SizedBox.shrink();

    return Column(
      children: packages.map((package) {
        final product = package.storeProduct;
        final isPremium = product.identifier.contains('premium');
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PurchaseButton(
            title: isPremium ? l10n.abonnementPremium : l10n.abonnementBasic,
            price: isAnnual
                ? l10n.paywallParAn(product.priceString)
                : l10n.paywallParMois(product.priceString),
            isPrimary: isPremium,
            onTap: () => onPurchase(package),
          ),
        );
      }).toList(),
    );
  }
}

class _PurchaseButton extends StatelessWidget {
  final String title;
  final String price;
  final bool isPrimary;
  final VoidCallback onTap;

  const _PurchaseButton({
    required this.title,
    required this.price,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? AppColors.primaryBlue : AppColors.primaryBlue.withAlpha(20),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isPrimary ? Colors.white : AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      price,
                      style: TextStyle(
                        color: isPrimary ? Colors.white70 : AppColors.primaryBlue.withAlpha(180),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isPrimary ? Colors.white70 : AppColors.primaryBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
