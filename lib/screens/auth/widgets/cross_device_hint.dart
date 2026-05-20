import 'dart:io';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// One-line hint shown above the Apple / magic-link buttons on login
/// and signup pages. Pre-empts the "Hide my email" trap on iOS Apple
/// Sign-In and reminds magic-link users to keep one email across
/// their devices.
///
/// Wording shifts per platform — iOS surfaces the Apple-specific
/// guidance ("Share my email" vs Hide), other platforms get a
/// generic "use the same address everywhere" line.
class CrossDeviceHint extends StatelessWidget {
  const CrossDeviceHint({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isApplePlatform = Platform.isIOS || Platform.isMacOS;
    final text = isApplePlatform
        ? l10n.crossDeviceHintApple
        : l10n.crossDeviceHintGeneric;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.devices, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
