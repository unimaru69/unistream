#!/usr/bin/env bash
# Synthetic, redistributable tones; no movie or client media in the test bundle.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/tvos/UniStreamTV/UniStreamTVTests/Fixtures"
mkdir -p "$DEST"
for codec in truehd ac3 dca; do
    name="$codec"
    [[ "$codec" != dca ]] || name=dts
    ffmpeg -hide_banner -loglevel error -f lavfi \
        -i 'sine=frequency=440:duration=3:sample_rate=48000' \
        -ac 6 -channel_layout '5.1(side)' -c:a "$codec" -strict -2 \
        -y "$DEST/$name-5.1.mka"
done
ffmpeg -hide_banner -loglevel error -f lavfi \
    -i 'sine=frequency=440:duration=8:sample_rate=48000' \
    -map 0:a -map 0:a -ac 6 -channel_layout '5.1(side)' \
    -c:a:0 ac3 -c:a:1 truehd -strict -2 \
    -metadata:s:a:0 language=fra -metadata:s:a:1 language=eng \
    -y "$DEST/ac3-truehd-switch.mka"
ffmpeg -hide_banner -loglevel error -f lavfi \
    -i 'testsrc=size=320x180:rate=24:duration=4' -f lavfi \
    -i 'sine=frequency=440:duration=4:sample_rate=48000' \
    -ac 6 -channel_layout '5.1(side)' -c:v libx264 -pix_fmt yuv420p \
    -preset ultrafast -c:a truehd -strict -2 -shortest -y "$DEST/h264-truehd.mkv"
