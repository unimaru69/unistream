import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';

void showSpeedPicker(BuildContext context, {
  required double currentSpeed,
  required void Function(double speed) onSpeedChanged,
}) {
  final tc = AppThemeColors.of(context);
  const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  showModalBottomSheet(
    context: context,
    backgroundColor: tc.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setLocal) {
        double localSpeed = currentSpeed;
        return RadioGroup<double>(
          groupValue: localSpeed,
          onChanged: (v) {
            if (v == null) return;
            localSpeed = v;
            setLocal(() {});
            onSpeedChanged(v);
          },
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Semantics(
                  header: true,
                  child: Text(AppLocalizations.of(context)!.vitesseLecture,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              ...speeds.map((sp) => ListTile(
                dense: true,
                leading: Radio<double>(
                  value: sp,
                  activeColor: AppColors.primaryBlue,
                ),
                title: Text(sp == 1.0 ? AppLocalizations.of(context)!.normaleVitesse : '$sp\u00d7',
                    style: const TextStyle(fontSize: 13)),
                onTap: () {
                  localSpeed = sp;
                  setLocal(() {});
                  onSpeedChanged(sp);
                },
              )),
              const SizedBox(height: 16),
            ]),
          ),
        );
      },
    ),
  );
}

void showAspectRatioPicker(BuildContext context, {
  required String currentRatio,
  required void Function(String ratio) onRatioSelected,
}) {
  final options = [
    ('auto', 'Auto'),
    ('16:9', '16:9'),
    ('4:3', '4:3'),
    ('2.35:1', '2.35:1'),
    ('stretch', AppLocalizations.of(context)!.etirer),
  ];
  final tc = AppThemeColors.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: tc.surface,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              header: true,
              child: Text(AppLocalizations.of(context)!.ratioAspect, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          for (final (value, label) in options)
            ListTile(
              dense: true,
              leading: Icon(
                currentRatio == value ? Icons.check_circle : Icons.circle_outlined,
                color: currentRatio == value ? AppColors.primaryBlue : tc.textDisabled,
                size: 20,
              ),
              title: Text(label),
              onTap: () {
                Navigator.pop(ctx);
                onRatioSelected(value);
              },
            ),
        ],
      ),
    ),
  );
}
