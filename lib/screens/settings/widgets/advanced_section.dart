import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';
import 'package:unistream/repositories/content_repository.dart';
import 'package:unistream/repositories/preferences_repository.dart';

class AdvancedSection extends ConsumerStatefulWidget {
  const AdvancedSection({super.key});

  @override
  ConsumerState<AdvancedSection> createState() => _AdvancedSectionState();
}

class _AdvancedSectionState extends ConsumerState<AdvancedSection> {
  double _maxRetries = 3;
  double _timeoutSec = 15;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  Future<void> _loadValues() async {
    final prefs = ref.read(preferencesRepositoryProvider);
    final retries = await prefs.getRetryMaxAttempts();
    final timeout = await prefs.getRetryTimeoutSec();
    if (!mounted) return;
    setState(() {
      _maxRetries = retries.toDouble();
      _timeoutSec = timeout.toDouble();
    });
  }

  Future<void> _saveMaxRetries(double value) async {
    setState(() => _maxRetries = value);
    final prefs = ref.read(preferencesRepositoryProvider);
    await prefs.setRetryMaxAttempts(value.round());
    await ref.read(contentRepositoryProvider).loadRetryConfig();
  }

  Future<void> _saveTimeout(double value) async {
    setState(() => _timeoutSec = value);
    final prefs = ref.read(preferencesRepositoryProvider);
    await prefs.setRetryTimeoutSec(value.round());
    await ref.read(contentRepositoryProvider).loadRetryConfig();
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: tc.divider),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            header: true,
            child: Text(l10n.reglagesAvances,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: tc.textDisabled,
                    letterSpacing: 1)),
          ),
        ),
        const SizedBox(height: 12),
        // Max retries slider
        Row(
          children: [
            Expanded(
              child: Text(l10n.tentativesMax,
                  style: const TextStyle(fontSize: 14)),
            ),
            Text('${_maxRetries.round()}',
                style: TextStyle(fontSize: 14, color: tc.textSecondary)),
          ],
        ),
        Slider(
          value: _maxRetries,
          min: 1,
          max: 5,
          divisions: 4,
          label: '${_maxRetries.round()}',
          onChanged: (v) => setState(() => _maxRetries = v),
          onChangeEnd: _saveMaxRetries,
        ),
        const SizedBox(height: 8),
        // Timeout slider
        Row(
          children: [
            Expanded(
              child: Text(l10n.delaiConnexion,
                  style: const TextStyle(fontSize: 14)),
            ),
            Text('${_timeoutSec.round()}s',
                style: TextStyle(fontSize: 14, color: tc.textSecondary)),
          ],
        ),
        Slider(
          value: _timeoutSec,
          min: 5,
          max: 30,
          divisions: 25,
          label: '${_timeoutSec.round()}s',
          onChanged: (v) => setState(() => _timeoutSec = v),
          onChangeEnd: _saveTimeout,
        ),
        const SizedBox(height: 8),
        Text(l10n.descriptionAvances,
            style: TextStyle(fontSize: 11, color: tc.textDisabled)),
      ],
    );
  }
}
