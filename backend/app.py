import os
from typing import Optional

import yt_dlp
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

app = FastAPI(title="harbor-resolver")

API_KEY = os.environ.get("API_KEY")


class ResolveRequest(BaseModel):
    url: str


class MediaVariant(BaseModel):
    id: str
    type: str  # "video" | "audio" — matches Dart's MediaType enum names
    label: str
    container: str
    codec: Optional[str] = None
    bitrateKbps: Optional[int] = None
    estimatedSizeBytes: Optional[int] = None
    streamUrl: str
    audioStreamUrl: Optional[str] = None
    requiresMuxing: bool = False
    needsAudioExtraction: bool = False


class ResolveResponse(BaseModel):
    title: str
    thumbnailUrl: Optional[str] = None
    durationSeconds: int = 0
    source: str
    variants: list[MediaVariant]


def _source_for(url: str) -> str:
    if "youtube.com" in url or "youtu.be" in url:
        return "youtube"
    if "instagram.com" in url:
        return "instagram"
    if "facebook.com" in url or "fb.watch" in url:
        return "facebook"
    return "unknown"


def _best_audio_format(formats: list[dict]) -> Optional[dict]:
    audio_only = [f for f in formats if f.get("vcodec") == "none" and f.get("acodec") != "none"]
    if not audio_only:
        return None
    return max(audio_only, key=lambda f: f.get("abr") or 0)


def _build_variants(info: dict) -> list[MediaVariant]:
    formats = info.get("formats") or []
    variants: list[MediaVariant] = []

    best_audio = _best_audio_format(formats)
    saw_audio_only = best_audio is not None

    for f in formats:
        vcodec = f.get("vcodec")
        acodec = f.get("acodec")
        stream_url = f.get("url")
        if not stream_url:
            continue

        has_video = vcodec not in (None, "none")
        has_audio = acodec not in (None, "none")

        size = f.get("filesize") or f.get("filesize_approx")
        bitrate = f.get("tbr") or f.get("vbr") or f.get("abr")

        if has_video and has_audio:
            # Muxed — simplest case, downloads and plays as-is.
            variants.append(
                MediaVariant(
                    id=f"v_{f.get('format_id')}",
                    type="video",
                    label=f.get("format_note") or f.get("resolution") or f.get("format_id", ""),
                    container=f.get("ext", "mp4"),
                    codec=vcodec,
                    bitrateKbps=int(bitrate) if bitrate else None,
                    estimatedSizeBytes=int(size) if size else None,
                    streamUrl=stream_url,
                )
            )
        elif has_video and not has_audio:
            # Video-only adaptive stream — needs the best audio track muxed
            # in after download (same path YouTube's 1080p+ already uses).
            variants.append(
                MediaVariant(
                    id=f"v_{f.get('format_id')}",
                    type="video",
                    label=f.get("format_note") or f.get("resolution") or f.get("format_id", ""),
                    container="mp4",
                    codec=vcodec,
                    bitrateKbps=int(bitrate) if bitrate else None,
                    estimatedSizeBytes=int(size) if size else None,
                    streamUrl=stream_url,
                    audioStreamUrl=best_audio["url"] if best_audio else None,
                    requiresMuxing=best_audio is not None,
                )
            )
        elif has_audio and not has_video:
            variants.append(
                MediaVariant(
                    id=f"a_{f.get('format_id')}",
                    type="audio",
                    label=f"{int(bitrate)} kbps" if bitrate else "Audio",
                    container=f.get("ext", "m4a"),
                    codec=acodec,
                    bitrateKbps=int(bitrate) if bitrate else None,
                    estimatedSizeBytes=int(size) if size else None,
                    streamUrl=stream_url,
                )
            )

    # Sources like Instagram/Facebook typically only expose muxed formats —
    # no genuine audio-only stream. Offer an "Audio only" option anyway,
    # backed by the client's native extraction path (MuxService.extractAudio)
    # instead of silently having no audio option at all.
    if not saw_audio_only:
        muxed = [v for v in variants if v.type == "video"]
        if muxed:
            best_muxed = max(muxed, key=lambda v: v.bitrateKbps or 0)
            variants.append(
                MediaVariant(
                    id="a_extracted",
                    type="audio",
                    label="Audio only",
                    container="m4a",
                    streamUrl=best_muxed.streamUrl,
                    needsAudioExtraction=True,
                )
            )

    return variants


@app.post("/resolve", response_model=ResolveResponse)
def resolve(req: ResolveRequest, x_api_key: Optional[str] = Header(default=None)):
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")

    ydl_opts = {"quiet": True, "no_warnings": True, "skip_download": True}
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(req.url, download=False)
    except yt_dlp.utils.DownloadError as e:
        raise HTTPException(status_code=422, detail=str(e)) from e

    variants = _build_variants(info)
    if not variants:
        raise HTTPException(status_code=422, detail="No downloadable media found for this URL.")

    return ResolveResponse(
        title=info.get("title") or "Untitled",
        thumbnailUrl=info.get("thumbnail"),
        durationSeconds=int(info.get("duration") or 0),
        source=_source_for(req.url),
        variants=variants,
    )


@app.get("/health")
def health():
    return {"status": "ok"}
