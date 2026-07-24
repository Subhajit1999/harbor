FROM python:3.12-slim

WORKDIR /app

# ffmpeg backs the /stream endpoint's server-side remux/mux and, when the
# source codec isn't iOS-safe (VP9/AV1 video, Opus audio), a real h264/aac
# transcode via libx264 — Debian's ffmpeg package ships libx264 built in,
# so no build-from-source needed.
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Render (and most PaaS hosts) inject the port to listen on via $PORT —
# shell form so the env var actually expands, unlike Docker's exec-form CMD.
CMD uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}
