import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme_colors.dart';
import '../../../providers/tmdb_provider.dart';

/// Settings block for the TMDB metadata enrichment feature.
///   - toggle on/off
///   - paste your own TMDB API key (overrides the build-time one)
///   - inline sign-up link
class TmdbSection extends ConsumerStatefulWidget {
  const TmdbSection({super.key});

  @override
  ConsumerState<TmdbSection> createState() => _TmdbSectionState();
}

class _TmdbSectionState extends ConsumerState<TmdbSection> {
  late final TextEditingController _ctrl;
  bool _showKey = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(tmdbConfigProvider);
    // Only pre-fill the field with the user's own override, never the baked
    // build-time key (which we want to stay opaque).
    _ctrl = TextEditingController(text: cfg.apiKey);
    _ctrl.addListener(() => setState(() => _dirty = true));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final cfg = ref.watch(tmdbConfigProvider);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.auto_awesome, color: tc.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text('Métadonnées TMDB',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 4),
            Text(
              "Enrichit les films et séries sans synopsis avec les infos de "
              "The Movie Database (synopsis, affiche, arrière-plan, casting, "
              "bande-annonce).",
              style: TextStyle(color: tc.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activer l\'enrichissement'),
              subtitle: Text(
                cfg.apiKey.isEmpty
                    ? 'Une clé TMDB est requise ci-dessous.'
                    : 'TMDB sera consulté pour les films/séries sans synopsis.',
                style: TextStyle(fontSize: 11, color: tc.textTertiary),
              ),
              value: cfg.enabled,
              onChanged: (v) =>
                  ref.read(tmdbConfigProvider.notifier).setEnabled(v),
            ),

            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              obscureText: !_showKey,
              decoration: InputDecoration(
                labelText: 'Clé API TMDB (v3)',
                hintText: 'Collez votre clé personnelle ici',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: IconButton(
                  icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(
                onPressed: () async {
                  const url = 'https://www.themoviedb.org/settings/api';
                  await Clipboard.setData(const ClipboardData(text: url));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lien copié — themoviedb.org/settings/api'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Obtenir une clé gratuite'),
              ),
              const Spacer(),
              if (_dirty)
                FilledButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Enregistrer'),
                  onPressed: () async {
                    await ref
                        .read(tmdbConfigProvider.notifier)
                        .setUserKey(_ctrl.text);
                    setState(() => _dirty = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Clé TMDB enregistrée')),
                      );
                    }
                  },
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
