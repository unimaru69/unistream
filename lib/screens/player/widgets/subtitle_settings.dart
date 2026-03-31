import 'package:flutter/material.dart';

void showSubtitleStylePicker(BuildContext context, {
  required double fontSize,
  required Color color,
  required double bgOpacity,
  required void Function(double fontSize) onFontSizeChanged,
  required void Function(Color color) onColorChanged,
  required void Function(double opacity) onBgOpacityChanged,
  required VoidCallback onDismissed,
}) {
  final colorOptions = <(Color, String)>[
    (Colors.white, 'Blanc'),
    (Colors.yellow, 'Jaune'),
    (Colors.green, 'Vert'),
    (Colors.cyan, 'Cyan'),
  ];

  // Local mutable copies for StatefulBuilder
  double localFontSize = fontSize;
  Color localColor = color;
  double localBgOpacity = bgOpacity;

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF12122A),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setLocal) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Style des sous-titres',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Text('Taille', style: TextStyle(fontSize: 13, color: Colors.white70)),
              Expanded(
                child: Slider(
                  value: localFontSize,
                  min: 12, max: 48, divisions: 18,
                  label: localFontSize.round().toString(),
                  activeColor: const Color(0xFF4A90D9),
                  onChanged: (v) {
                    setLocal(() => localFontSize = v);
                    onFontSizeChanged(v);
                  },
                ),
              ),
              Text('${localFontSize.round()}',
                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Text('Couleur', style: TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(width: 16),
              ...colorOptions.map((opt) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    setLocal(() => localColor = opt.$1);
                    onColorChanged(opt.$1);
                  },
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: opt.$1, shape: BoxShape.circle,
                      border: Border.all(
                        color: localColor.toARGB32() == opt.$1.toARGB32()
                            ? const Color(0xFF4A90D9) : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Text('Fond', style: TextStyle(fontSize: 13, color: Colors.white70)),
              Expanded(
                child: Slider(
                  value: localBgOpacity,
                  min: 0, max: 1, divisions: 10,
                  label: '${(localBgOpacity * 100).round()}%',
                  activeColor: const Color(0xFF4A90D9),
                  onChanged: (v) {
                    setLocal(() => localBgOpacity = v);
                    onBgOpacityChanged(v);
                  },
                ),
              ),
              Text('${(localBgOpacity * 100).round()}%',
                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ]),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    ),
  ).then((_) => onDismissed());
}
