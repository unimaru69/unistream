import 'package:flutter/material.dart';
import '../core/colors.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: isError ? Colors.redAccent : AppColors.darkSurface,
    duration: duration,
    action: actionLabel != null && onAction != null
        ? SnackBarAction(label: actionLabel, onPressed: onAction, textColor: Colors.white)
        : null,
  ));
}
