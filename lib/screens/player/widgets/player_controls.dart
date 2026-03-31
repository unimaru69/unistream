import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/strings.dart';

void showSpeedPicker(BuildContext context, {
  required double currentSpeed,
  required void Function(double speed) onSpeedChanged,
}) {
  const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setLocal) {
        double localSpeed = currentSpeed;
        return SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(AppStrings.vitesseLecture,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            ...speeds.map((sp) => RadioListTile<double>(
              dense: true,
              title: Text(sp == 1.0 ? 'Normale (1\u00d7)' : '${sp}\u00d7',
                  style: const TextStyle(fontSize: 13)),
              value: sp,
              groupValue: localSpeed,
              activeColor: AppColors.primaryBlue,
              onChanged: (v) {
                if (v == null) return;
                localSpeed = v;
                setLocal(() {});
                onSpeedChanged(v);
              },
            )),
            const SizedBox(height: 16),
          ]),
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
    ('stretch', '\u00c9tirer'),
  ];
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.darkText,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(AppStrings.ratioAspect, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          for (final (value, label) in options)
            ListTile(
              dense: true,
              leading: Icon(
                currentRatio == value ? Icons.check_circle : Icons.circle_outlined,
                color: currentRatio == value ? AppColors.primaryBlue : Colors.white38,
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
