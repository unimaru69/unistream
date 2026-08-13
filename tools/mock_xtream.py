#!/usr/bin/env python3
"""Mock Xtream Codes panel serving a REALISTIC-SCALE catalog.

Purpose: reproduce the Android TV freeze/crash that only happens with a
real provider (tens of thousands of items) — includes the provider quirks
recorded in project memory: duplicate stream_ids, empty ids, numeric vs
string fields, base64 EPG titles.
"""
import base64
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

N_LIVE = 12000
N_VOD = 30000
N_SERIES = 6000
N_LIVE_CATS = 120
N_VOD_CATS = 150
N_SERIES_CATS = 80

def b64(s):
    return base64.b64encode(s.encode()).decode()

NOW = int(time.time())

def live_streams():
    out = []
    for i in range(1, N_LIVE + 1):
        sid = i
        # Provider quirks: every 500th item DUPLICATES the previous id,
        # every 777th has an EMPTY id.
        if i % 500 == 0:
            sid = i - 1
        entry = {
            "num": i,
            "name": f"FR| CHAINE {i} FHD",
            "stream_type": "live",
            "stream_id": "" if i % 777 == 0 else sid,
            "stream_icon": f"http://10.0.2.2:8899/logo/{i}.png",
            "epg_channel_id": f"chan{i}.fr",
            "added": str(NOW - i),
            "category_id": str((i % N_LIVE_CATS) + 1),
            "tv_archive": 1 if i % 3 == 0 else 0,
            "tv_archive_duration": "3" if i % 3 == 0 else "0",
            "custom_sid": "",
            "direct_source": "",
        }
        out.append(entry)
    return out

def vod_streams():
    out = []
    for i in range(1, N_VOD + 1):
        out.append({
            "num": i,
            "name": f"Film Exemple {i} (2024) MULTI 4K",
            "stream_type": "movie",
            "stream_id": 100000 + i,
            "stream_icon": f"http://10.0.2.2:8899/poster/{i}.jpg",
            "rating": "7.4",
            "rating_5based": 3.7,
            "added": str(NOW - i * 60),
            "category_id": str((i % N_VOD_CATS) + 1),
            "container_extension": "mkv",
            "custom_sid": "",
            "direct_source": "",
        })
    return out

def series():
    out = []
    for i in range(1, N_SERIES + 1):
        out.append({
            "num": i,
            "name": f"Serie Exemple {i} SAISON COMPLETE",
            "series_id": 500000 + i,
            "cover": f"http://10.0.2.2:8899/cover/{i}.jpg",
            "plot": "Un synopsis suffisamment long pour peser comme un vrai payload de panel Xtream, avec des détails et des phrases qui s'étirent." ,
            "cast": "Acteur Un, Actrice Deux, Acteur Trois",
            "director": "Réalisateur Exemple",
            "genre": "Drame / Action",
            "release_date": "2023-01-15",
            "last_modified": str(NOW - i * 120),
            "rating": "8",
            "rating_5based": 4.0,
            "category_id": str((i % N_SERIES_CATS) + 1),
        })
    return out

def cats(n, prefix):
    return [{"category_id": str(i + 1), "category_name": f"{prefix} {i + 1}",
             "parent_id": 0} for i in range(n)]

# Pre-serialize the big payloads once (server-side speed).
PAYLOADS = {}

def payload(key, builder):
    if key not in PAYLOADS:
        PAYLOADS[key] = json.dumps(builder()).encode()
    return PAYLOADS[key]

def short_epg(stream_id):
    listings = []
    for k in range(8):
        start = NOW + (k - 1) * 3600
        end = start + 3600
        listings.append({
            "id": f"{stream_id}{k}",
            "epg_id": "1",
            "title": b64(f"Programme {k} de la chaine {stream_id}"),
            "lang": "fr",
            "start": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(start)),
            "end": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(end)),
            "description": b64("Description du programme avec pas mal de texte pour faire réaliste. " * 4),
            "channel_id": f"chan{stream_id}.fr",
            "start_timestamp": str(start),
            "stop_timestamp": str(end),
        })
    return {"epg_listings": listings}

class H(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # keep the console quiet; we tail request counts separately

    def do_HEAD(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        action = (q.get("action") or [""])[0]
        body = b"[]"
        if u.path == "/player_api.php":
            if not action:
                body = json.dumps({
                    "user_info": {"auth": 1, "username": "test", "status": "Active",
                                   "exp_date": str(NOW + 86400 * 365), "max_connections": "1"},
                    "server_info": {"url": "10.0.2.2", "port": "8899",
                                     "server_protocol": "http", "timezone": "Europe/Paris"},
                }).encode()
            elif action == "get_live_categories":
                body = payload("live_cats", lambda: cats(N_LIVE_CATS, "LIVE FR"))
            elif action == "get_live_streams":
                body = payload("live", live_streams)
            elif action == "get_vod_categories":
                body = payload("vod_cats", lambda: cats(N_VOD_CATS, "FILMS"))
            elif action == "get_vod_streams":
                body = payload("vod", vod_streams)
            elif action == "get_series_categories":
                body = payload("series_cats", lambda: cats(N_SERIES_CATS, "SERIES"))
            elif action == "get_series":
                body = payload("series", series)
            elif action == "get_short_epg":
                sid = (q.get("stream_id") or ["0"])[0]
                body = json.dumps(short_epg(sid)).encode()
            elif action == "get_simple_data_table":
                sid = (q.get("stream_id") or ["0"])[0]
                body = json.dumps(short_epg(sid)).encode()
        elif u.path.startswith(("/logo/", "/poster/", "/cover/")):
            # 1x1 PNG — keeps image pipelines busy without huge bytes.
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            png = base64.b64decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
            self.send_header("Content-Length", str(len(png)))
            self.end_headers()
            self.wfile.write(png)
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

if __name__ == "__main__":
    for key, builder in [("live", live_streams), ("vod", vod_streams), ("series", series)]:
        data = payload(key, builder)
        print(f"{key}: {len(data)/1e6:.1f} MB")
    print("mock Xtream on :8899")
    ThreadingHTTPServer(("0.0.0.0", 8899), H).serve_forever()
