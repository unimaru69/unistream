import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logger.dart';
import '../services/xtream_api.dart';

/// Snapshot returned to the Live focused-preview panel. `null` ends
/// mean the channel has no cached EPG and the short-EPG fetch hasn't
/// resolved yet (or the provider doesn't ship EPG for that channel).
class LiveEpgSnapshot {
  const LiveEpgSnapshot({this.now, this.next});

  final EpgPreviewEntry? now;
  final EpgPreviewEntry? next;

  bool get isEmpty => now == null && next == null;
}

/// Reactively delivers the current + next EPG programme for a live
/// channel, prioritising the in-memory short-EPG cache and falling
/// back to a one-shot fetch on miss.
///
/// Used by the `FocusedItemPreview` Live variant — kept on the
/// channel grid hover path so we never block tile rendering.
final liveEpgPreviewProvider =
    FutureProvider.family<LiveEpgSnapshot, String>((ref, streamId) async {
  if (streamId.isEmpty) return const LiveEpgSnapshot();
  // Cache hit — return synchronously.
  final cached = XtreamApi.getCachedEpgPair(streamId);
  if (cached.now != null) {
    return LiveEpgSnapshot(now: cached.now, next: cached.next);
  }
  // Cache miss — fire the short-EPG fetch. After it populates the
  // cache, re-query for the structured pair. Failure (no EPG for
  // this channel, network down) → return empty so the preview shows
  // a quiet "Aucune info" line.
  try {
    await XtreamApi.getShortEpg(streamId, limit: 8);
  } catch (e, st) {
    AppLogger.warning(LogModule.epg,
        'live preview short EPG fetch failed for $streamId',
        error: e, stackTrace: st);
    return const LiveEpgSnapshot();
  }
  final reread = XtreamApi.getCachedEpgPair(streamId);
  return LiveEpgSnapshot(now: reread.now, next: reread.next);
});
