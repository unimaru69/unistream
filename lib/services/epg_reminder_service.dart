import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logger.dart';

/// A reminder for an upcoming EPG program.
class EpgReminder {
  final String streamId;
  final String channelName;
  final String programTitle;
  final DateTime startUtc;
  final int durationMin;
  /// Minutes before start to trigger the reminder.
  final int alertMinutesBefore;

  const EpgReminder({
    required this.streamId,
    required this.channelName,
    required this.programTitle,
    required this.startUtc,
    required this.durationMin,
    this.alertMinutesBefore = 5,
  });

  String get id => '${streamId}_${startUtc.millisecondsSinceEpoch}';

  DateTime get alertTime => startUtc.subtract(Duration(minutes: alertMinutesBefore));

  bool get isExpired => DateTime.now().toUtc().isAfter(startUtc);

  Map<String, dynamic> toJson() => {
    'streamId': streamId,
    'channelName': channelName,
    'programTitle': programTitle,
    'startUtc': startUtc.toIso8601String(),
    'durationMin': durationMin,
    'alertMinutesBefore': alertMinutesBefore,
  };

  factory EpgReminder.fromJson(Map<String, dynamic> j) => EpgReminder(
    streamId: j['streamId'] as String,
    channelName: j['channelName'] as String,
    programTitle: j['programTitle'] as String,
    startUtc: DateTime.parse(j['startUtc'] as String),
    durationMin: j['durationMin'] as int,
    alertMinutesBefore: j['alertMinutesBefore'] as int? ?? 5,
  );
}

/// Manages EPG program reminders with periodic in-app alerts.
class EpgReminderService {
  static const _prefsKey = 'epg_reminders';
  static final EpgReminderService instance = EpgReminderService._();
  EpgReminderService._();

  final ValueNotifier<List<EpgReminder>> reminders = ValueNotifier([]);
  Timer? _checkTimer;
  void Function(EpgReminder reminder)? _onAlert;
  final Set<String> _firedAlerts = {};

  /// Initialize: load reminders and start periodic check.
  Future<void> init({required void Function(EpgReminder reminder) onAlert}) async {
    _onAlert = onAlert;
    await _load();
    _cleanExpired();
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  void dispose() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => EpgReminder.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      reminders.value = list;
    } catch (e, st) {
      AppLogger.warning(LogModule.config, 'Failed to load EPG reminders', error: e, stackTrace: st);
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, jsonEncode(reminders.value.map((r) => r.toJson()).toList()));
  }

  /// Add a reminder for a program.
  Future<void> add(EpgReminder reminder) async {
    final list = List<EpgReminder>.from(reminders.value);
    // Avoid duplicates
    list.removeWhere((r) => r.id == reminder.id);
    list.add(reminder);
    reminders.value = list;
    await _save();
  }

  /// Remove a reminder by ID.
  Future<void> remove(String reminderId) async {
    final list = List<EpgReminder>.from(reminders.value);
    list.removeWhere((r) => r.id == reminderId);
    reminders.value = list;
    _firedAlerts.remove(reminderId);
    await _save();
  }

  /// Check if a reminder exists for this program.
  bool hasReminder(String streamId, DateTime startUtc) {
    final id = '${streamId}_${startUtc.millisecondsSinceEpoch}';
    return reminders.value.any((r) => r.id == id);
  }

  /// Clean up expired reminders.
  void _cleanExpired() {
    final list = List<EpgReminder>.from(reminders.value);
    final before = list.length;
    list.removeWhere((r) => r.isExpired);
    if (list.length != before) {
      reminders.value = list;
      _save();
    }
  }

  /// Periodic check — fire alerts for upcoming programs.
  void _check() {
    _cleanExpired();
    final now = DateTime.now().toUtc();
    for (final r in reminders.value) {
      if (_firedAlerts.contains(r.id)) continue;
      if (now.isAfter(r.alertTime) && now.isBefore(r.startUtc)) {
        _firedAlerts.add(r.id);
        _onAlert?.call(r);
      }
    }
  }
}
