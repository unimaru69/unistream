import 'package:flutter/material.dart';
import 'package:unistream/core/colors.dart';
import 'package:unistream/core/theme_colors.dart';
import 'package:unistream/l10n/app_localizations.dart';

/// A parsed HLS variant from a master playlist.
class HlsVariant {
  final String url;
  final int bandwidth;
  final int? width;
  final int? height;
  final String? name;

  const HlsVariant({
    required this.url,
    required this.bandwidth,
    this.width,
    this.height,
    this.name,
  });

  String get label {
    if (height != null && height! > 0) {
      final tag = height! >= 2160
          ? '4K'
          : height! >= 1080
              ? 'FHD'
              : height! >= 720
                  ? 'HD'
                  : 'SD';
      return '${height}p ($tag)';
    }
    if (name != null && name!.isNotEmpty) return name!;
    final mbps = (bandwidth / 1000000).toStringAsFixed(1);
    return '$mbps Mbps';
  }
}

/// Parse a master M3U8 playlist into variants.
/// Returns empty list if it's not a master playlist (single-variant).
List<HlsVariant> parseHlsMasterPlaylist(String content, String baseUrl) {
  final lines = content.split('\n');
  final variants = <HlsVariant>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;

    // Parse attributes
    final attrs = line.substring('#EXT-X-STREAM-INF:'.length);
    final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(attrs);
    final resMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(attrs);
    final nameMatch = RegExp(r'NAME="([^"]*)"').firstMatch(attrs);

    if (bwMatch == null) continue;

    // Next non-comment line is the URL
    String? variantUrl;
    for (int j = i + 1; j < lines.length; j++) {
      final next = lines[j].trim();
      if (next.isEmpty || next.startsWith('#')) continue;
      variantUrl = next;
      break;
    }
    if (variantUrl == null) continue;

    // Resolve relative URLs
    if (!variantUrl.startsWith('http')) {
      final uri = Uri.parse(baseUrl);
      final basePath = uri.path.substring(0, uri.path.lastIndexOf('/') + 1);
      variantUrl = uri.replace(path: '$basePath$variantUrl').toString();
    }

    variants.add(HlsVariant(
      url: variantUrl,
      bandwidth: int.parse(bwMatch.group(1)!),
      width: resMatch != null ? int.tryParse(resMatch.group(1)!) : null,
      height: resMatch != null ? int.tryParse(resMatch.group(2)!) : null,
      name: nameMatch?.group(1),
    ));
  }

  // Sort by bandwidth descending (highest quality first)
  variants.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
  return variants;
}

void showQualityPicker(BuildContext context, {
  required String qualityBadge,
  required String bitrate,
  required List<HlsVariant> variants,
  required String? activeVariantUrl,
  required void Function(HlsVariant? variant) onVariantSelected,
}) {
  final tc = AppThemeColors.of(context);
  final l10n = AppLocalizations.of(context)!;
  showModalBottomSheet(
    context: context,
    backgroundColor: tc.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.qualiteStream,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (qualityBadge.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.qualiteActuelle(
                      bitrate.isNotEmpty ? '$qualityBadge ($bitrate)' : qualityBadge,
                    ),
                    style: TextStyle(fontSize: 12, color: tc.textDisabled),
                  ),
                ],
              ],
            ),
          ),
          if (variants.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l10n.qualiteUniqueDisponible,
                  style: TextStyle(fontSize: 13, color: tc.textDisabled)),
            )
          else ...[
            // Auto option (original URL)
            ListTile(
              dense: true,
              leading: Icon(
                activeVariantUrl == null ? Icons.radio_button_checked : Icons.radio_button_off,
                color: activeVariantUrl == null ? AppColors.primaryBlue : tc.textDisabled,
                size: 20,
              ),
              title: Text(l10n.qualiteAuto, style: const TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                onVariantSelected(null);
              },
            ),
            for (final v in variants)
              ListTile(
                dense: true,
                leading: Icon(
                  activeVariantUrl == v.url ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: activeVariantUrl == v.url ? AppColors.primaryBlue : tc.textDisabled,
                  size: 20,
                ),
                title: Text(v.label, style: const TextStyle(fontSize: 14)),
                subtitle: Text('${(v.bandwidth / 1000000).toStringAsFixed(1)} Mbps',
                    style: TextStyle(fontSize: 11, color: tc.textDisabled)),
                onTap: () {
                  Navigator.pop(ctx);
                  onVariantSelected(v);
                },
              ),
          ],
        ],
      ),
    ),
  );
}
