FROM python:3.12-slim

WORKDIR /app

# ffmpeg backs the /stream endpoint's server-side remux (video-only +
# audio-only DASH tracks -> one combined file) — stream-copy only, no
# re-encode, so this doesn't need a build from source or extra codecs.
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Render (and most PaaS hosts) inject the port to listen on via $PORT —
# shell form so the env var actually expands, unlike Docker's exec-form CMD.
CMD uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}
