# Harbor resolver backend

Small FastAPI service wrapping [yt-dlp](https://github.com/yt-dlp/yt-dlp) so
Harbor can resolve YouTube/Instagram/Facebook links into direct media URLs
server-side, instead of relying only on the app's built-in HTML scrapers
(see `lib/data/resolvers/`). The app calls this **only** to resolve a URL —
actual video/audio bytes still download straight from the source's CDN to
the device, this service never proxies media.

Not part of the Flutter build — a separate service you deploy and point
Harbor at via Settings.

## Run locally

```bash
docker build -t harbor-resolver .
docker run -p 8000:8000 -e API_KEY=some-secret harbor-resolver
```

```bash
curl -X POST http://localhost:8000/resolve \
  -H "X-API-Key: some-secret" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.instagram.com/reel/XXXXXXXXX/"}'
```

## Deploy to Render

1. Push this repo to GitHub (if not already).
2. In the Render dashboard: **New → Blueprint**, point it at the repo.
   Render picks up `render.yaml` automatically and provisions a Docker web
   service named `harbor-resolver`.
3. When prompted, set the `API_KEY` env var to any secret string of your
   choosing — this is the same value you'll enter in Harbor's Settings, and
   it's what stops anyone else who finds your `.onrender.com` URL from
   using it as a free yt-dlp proxy.
4. Once deployed, copy the service URL (`https://harbor-resolver-xxxx.onrender.com`).
5. In Harbor → Settings → Advanced, paste that URL into **Resolver Server
   URL** and your chosen secret into **Resolver API Key**.

### "Unable to extract video url" errors

`requirements.txt` deliberately doesn't pin `yt-dlp` — the extractors it
relies on for Instagram/YouTube/Facebook break periodically as those sites
change, and yt-dlp's maintainers ship fixes fast, so pinning a version just
means it silently goes stale. If you see this error, redeploy (Render's
"Manual Deploy" button, or push any commit) to pick up the current release.

### Free tier caveat

Render's free plan spins the service down after 15 minutes idle. The first
resolve request after a period of inactivity will be slow (cold start,
often 10s–60s+) while it spins back up — expected, not a bug. Upgrade to a
paid instance type if that's not acceptable.

## API

### `POST /resolve`

Headers: `X-API-Key: <your secret>` (required if `API_KEY` is set).

Body: `{"url": "<youtube/instagram/facebook link>"}`

Response shape matches Harbor's `MediaMetadata`/`MediaVariant` Dart classes
directly (see `lib/domain/entities/media_variant.dart`) so the client
doesn't need a translation layer:

```json
{
  "title": "...",
  "thumbnailUrl": "...",
  "durationSeconds": 42,
  "source": "instagram",
  "variants": [
    {
      "id": "v_137",
      "type": "video",
      "label": "720p",
      "container": "mp4",
      "streamUrl": "https://...",
      "requiresMuxing": false,
      "needsAudioExtraction": false
    }
  ]
}
```

### `GET /health`

Returns `{"status": "ok"}` — used by Render's health check.
