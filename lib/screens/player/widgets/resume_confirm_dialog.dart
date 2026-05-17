import 'package:flutter/material.dart';

import '../../../core/colors.dart';
import '../../../core/design_tokens.dart';
import '../../../core/typography.dart';
import '../../../l10n/app_localizations.dart';

/// Choice returned by [showResumeConfirmDialog].
///
/// `resume` → start playback from the saved position.
/// `restart` → start playback from 0 (and ideally clear saved progress).
/// `cancel` → user dismissed; do nothing.
enum ResumeChoice { resume, restart, cancel }

/// Apple-TV+-style "Reprendre la lecture ?" dialog. Mirror of
/// `tvos/UniStreamTV/UniStreamTV/Views/Player/ResumeConfirmView.swift`.
/// Shown before opening the player when the user taps a row / card
/// that already has non-trivial progress saved — gives them an
/// explicit choice instead of silently resuming.
///
/// Returns the user's [ResumeChoice]. `null` if the route is popped
/// by any other means (Esc, scrim tap, system back).
Future<ResumeChoice?> showResumeConfirmDialog({
  required BuildContext context,
  required String? title,
  required Duration position,
  required Duration? duration,
}) {
  return showDialog<ResumeChoice>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    barrierDismissible: true,
    builder: (ctx) {
      return _ResumeConfirmDialog(
        title: title,
        position: position,
        duration: duration,
      );
    },
  );
}

class _ResumeConfirmDialog extends StatelessWidget {
  const _ResumeConfirmDialog({
    required this.title,
    required this.position,
    required this.duration,
  });

  final String? title;
  final Duration position;
  final Duration? duration;

  String _fmtHMS(Duration d) {
    final total = d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (h > 0) return '$h:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final posText = _fmtHMS(position);
    final fraction = (duration != null && duration!.inSeconds > 0)
        ? (position.inSeconds / duration!.inSeconds).clamp(0.0, 1.0)
        : null;
    final percentLabel =
        fraction != null ? '${(fraction * 100).round()}% vu' : null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: DS.padding.screenHorizontal,
        vertical: DS.space.xxl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          padding: EdgeInsets.all(DS.space.xxl),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(DS.radius.hero),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                l10n.reprendreLecture,
                style: DSText.title1.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              if (title != null && title!.isNotEmpty) ...<Widget>[
                SizedBox(height: DS.space.xs),
                Text(
                  title!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: DSText.body.copyWith(
                    color: DS.colour.textSecondary,
                  ),
                ),
              ],
              SizedBox(height: DS.space.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.access_time,
                      size: 18, color: AppColors.primaryBlueLighter),
                  SizedBox(width: DS.space.xs),
                  Text(
                    posText,
                    style: DSText.bodyEmphasised.copyWith(
                      color: AppColors.primaryBlueLighter,
                    ),
                  ),
                  if (percentLabel != null) ...<Widget>[
                    Text('  ·  ',
                        style: DSText.body
                            .copyWith(color: DS.colour.textTertiary)),
                    Text(
                      percentLabel,
                      style: DSText.body.copyWith(
                        color: AppColors.primaryBlueLighter,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: DS.space.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _ChoiceCard(
                    icon: Icons.replay,
                    title: l10n.recommencer,
                    subtitle: l10n.depuisLeDebut,
                    accent: false,
                    onTap: () =>
                        Navigator.of(context).pop(ResumeChoice.restart),
                  ),
                  SizedBox(width: DS.space.lg),
                  _ChoiceCard(
                    icon: Icons.play_arrow,
                    title: l10n.reprendreSimple,
                    subtitle: l10n.reprendreDepuis(posText),
                    accent: true,
                    onTap: () =>
                        Navigator.of(context).pop(ResumeChoice.resume),
                  ),
                ],
              ),
              SizedBox(height: DS.space.md),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(ResumeChoice.cancel),
                style: TextButton.styleFrom(
                  foregroundColor: DS.colour.textSecondary,
                  shape: const StadiumBorder(),
                  padding: EdgeInsets.symmetric(
                    horizontal: DS.space.lg,
                    vertical: DS.space.sm,
                  ),
                ),
                child: Text(
                  l10n.annuler,
                  style: DSText.body.copyWith(
                    color: DS.colour.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatefulWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool accent;
  final VoidCallback onTap;

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHover(bool v) {
    if (_hovered == v || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    setState(() => _hovered = v);
  }

  void _setPress(bool v) {
    if (_pressed == v || !mounted) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.accent
        ? AppColors.primaryBlue
        : AppColors.darkSurfaceElevated;
    final scale =
        _pressed ? 0.97 : (_hovered ? DS.focus.cardScale : 1.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTapDown: (_) => _setPress(true),
        onTapUp: (_) => _setPress(false),
        onTapCancel: () => _setPress(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: DS.focus.animation,
          curve: DS.focus.curve,
          child: AnimatedContainer(
            duration: DS.focus.animation,
            curve: DS.focus.curve,
            width: 240,
            height: 160,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(DS.radius.card),
              border: _hovered
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: _hovered
                  ? <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: DS.focus.shadowOpacity,
                        ),
                        blurRadius: DS.focus.shadowRadius,
                        offset: Offset(0, DS.focus.shadowY),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(widget.icon, size: 40, color: Colors.white),
                SizedBox(height: DS.space.sm),
                Text(
                  widget.title,
                  style: DSText.title3.copyWith(color: Colors.white),
                ),
                SizedBox(height: DS.space.xxs),
                Text(
                  widget.subtitle,
                  style: DSText.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
