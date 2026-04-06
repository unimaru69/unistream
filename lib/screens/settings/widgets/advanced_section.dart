import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/storage_keys.dart';
import '../../../core/theme_colors.dart';
import '../../../services/xtream_api.dart';
import 'package:unistream/l10n/app_localizations.dart';

class AdvancedSection extends StatefulWidget {
  const AdvancedSection({super.key});

  @override
  State<AdvancedSection> createState() => _AdvancedSectionState();
}

class _AdvancedSectionState extends State<AdvancedSection> {
  double _maxRetries = 3;
  double _timeoutSec = 15;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  Future<void> _loadValues() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _maxRetries =
          (prefs.getInt(StorageKeys.retryMaxAttempts) ?? 3).toDouble();
      _timeoutSec =
          (prefs.getInt(StorageKeys.retryTimeoutSec) ?? 15).toDouble();
    });
  }

  Future<void> _saveMaxRetries(double value) async {
    setState(() => _maxRetries = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.retryMaxAttempts, value.round());
    await XtreamApi.loadRetryConfig();
  }

  Future<void> _saveTimeout(double value) async {
    setState(() => _timeoutSec = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.retryTimeoutSec, value.round());
    await XtreamApi.loadRetryConfig();
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
          child: Text(l10n.reglagesAvances,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: tc.textDisabled,
                  letterSpacing: 1)),
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
