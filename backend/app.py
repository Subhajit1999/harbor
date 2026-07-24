import logging
import os
import subprocess
import tempfile
from typing import Optional
from urllib.parse import quote

import yt_dlp
from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import FileResponse
from pydantic import BaseModel
from starlette.background import BackgroundTask

logger = logging.getLogger("harbor-resolver")

app = FastAPI(title="harbor-resolver")

API_KEY = os.environ.get("API_KEY")
if not API_KEY:
    logger.warning(
        "API_KEY is not set — /resolve is running with no authentication at all. "
        "Set API_KEY to require X-API-Key on every request."
    )

ALLOWED_HOSTS = ("youtube.com", "youtu.be", "instagram.com", "facebook.com", "fb.watch")


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


def _hostname(url: str) -> str:
    from urllib.parse import urlparse

    return (urlparse(url).hostname or "").lower()


def _is_allowed_host(hostname: str) -> bool:
    return any(hostname == h or hostname.endswith(f".{h}") for h in ALLOWED_HOSTS)


def _source_for(hostname: str) -> str:
    if hostname.endswith("youtube.com") or hostname.endswith("youtu.be"):
        return "youtube"
    if hostname.endswith("instagram.com"):
        return "instagram"
    if hostname.endswith("facebook.com") or hostname.endswith("fb.watch"):
        return "facebook"
    return "unknown"


def _best_audio_format(formats: list[dict]) -> Optional[dict]:
    audio_only = [f for f in formats if f.get("vcodec") == "none" and f.get("acodec") != "none"]
    if not audio_only:
        return None
    return max(audio_only, key=lambda f: f.get("abr") or 0)


def _needs_video_transcode(vcodec: Optional[str]) -> bool:
    if not vcodec or vcodec in ("none", ""):
        return False
    c = vcodec.lower()
    return c.startswith("vp09") or c.startswith("vp9") or c.startswith("av01") or c.startswith("av1")


def _needs_audio_transcode(acodec: Optional[str]) -> bool:
    if not acodec or acodec in ("none", ""):
        return False
    c = acodec.lower()
    return not (c.startswith("mp4a") or c.startswith("aac"))


def _stream_url(
    base_url: str,
    video_url: str,
    vcodec: Optional[str],
    audio_url: Optional[str] = None,
    acodec: Optional[str] = None,
) -> str:
    url = f"{base_url}stream?video={quote(video_url, safe='')}"
    if audio_url:
        url += f"&audio={quote(audio_url, safe='')}"
    if vcodec:
        url += f"&vcodec={quote(vcodec, safe='')}"
    if acodec:
        url += f"&acodec={quote(acodec, safe='')}"
    url += f"&key={quote(API_KEY or '', safe='')}"
    return url


def _build_variants(info: dict, base_url: str) -> list[MediaVariant]:
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
            # Muxed single-file format — both tracks already in one
            # container. Still route through /stream when the codec isn't
            # iOS-safe (e.g. Instagram's native VP9/Opus mp4s) so the
            # client always gets a playable h264/aac file; otherwise serve
            # the raw URL, no server CPU spent.
            needs_transcode = _needs_video_transcode(vcodec) or _needs_audio_transcode(acodec)
            final_url = (
                _stream_url(base_url, stream_url, vcodec, acodec=acodec)
                if needs_transcode
                else stream_url
            )
            variants.append(
                MediaVariant(
                    id=f"v_{f.get('format_id')}",
                    type="video",
                    label=f.get("format_note") or f.get("resolution") or f.get("format_id", ""),
                    container=f.get("ext", "mp4"),
                    codec=vcodec,
                    bitrateKbps=int(bitrate) if bitrate else None,
                    estimatedSizeBytes=int(size) if size else None,
                    streamUrl=final_url,
                )
            )
        elif has_video and not has_audio:
            # Video-only adaptive stream. If there's an audio track to pair
            # it with, mux (and transcode if needed) server-side via
            # /stream and hand back a single combined URL — the client
            # downloads one file, no local mux step, same as any other
            # video variant from any other source.
            if best_audio:
                combined_url = _stream_url(
                    base_url, stream_url, vcodec, audio_url=best_audio["url"], acodec=acodec
                )
                variants.append(
                    MediaVariant(
                        id=f"v_{f.get('format_id')}",
                        type="video",
                        label=f.get("format_note") or f.get("resolution") or f.get("format_id", ""),
                        container="mp4",
                        codec=vcodec,
                        bitrateKbps=int(bitrate) if bitrate else None,
                        estimatedSizeBytes=int(size) if size else None,
                        streamUrl=combined_url,
                    )
                )
            else:
                # No audio track exists anywhere for this source — nothing
                # to mux, but still transcode the video alone if needed.
                final_url = (
                    _stream_url(base_url, stream_url, vcodec)
                    if _needs_video_transcode(vcodec)
                    else stream_url
                )
                variants.append(
                    MediaVariant(
                        id=f"v_{f.get('format_id')}",
                        type="video",
                        label=f.get("format_note") or f.get("resolution") or f.get("format_id", ""),
                        container="mp4",
                        codec=vcodec,
                        bitrateKbps=int(bitrate) if bitrate else None,
                        estimatedSizeBytes=int(size) if size else None,
                        streamUrl=final_url,
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
def resolve(
    req: ResolveRequest, request: Request, x_api_key: Optional[str] = Header(default=None)
):
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")

    hostname = _hostname(req.url)
    if not hostname or not _is_allowed_host(hostname):
        raise HTTPException(
            status_code=400,
            detail="Only youtube.com, youtu.be, instagram.com, facebook.com, and fb.watch links are supported.",
        )

    ydl_opts = {"quiet": True, "no_warnings": True, "skip_download": True}
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(req.url, download=False)
    except yt_dlp.utils.DownloadError as e:
        raise HTTPException(status_code=422, detail=str(e)) from e
    except Exception:
        logger.exception("Unexpected error resolving url")
        raise HTTPException(status_code=500, detail="Failed to resolve this link.")

    try:
        variants = _build_variants(info, str(request.base_url))
    except Exception:
        logger.exception("Unexpected error building variants")
        raise HTTPException(status_code=500, detail="Failed to resolve this link.")

    if not variants:
        raise HTTPException(status_code=422, detail="No downloadable media found for this URL.")

    return ResolveResponse(
        title=info.get("title") or "Untitled",
        thumbnailUrl=info.get("thumbnail"),
        durationSeconds=int(info.get("duration") or 0),
        source=_source_for(hostname),
        variants=variants,
    )


@app.get("/stream")
def stream(
    video: str,
    audio: Optional[str] = None,
    vcodec: Optional[str] = None,
    acodec: Optional[str] = None,
    key: Optional[str] = None,
):
    # Query param, not a header — the Dart-side download client does a
    # plain GET with no custom headers, so this has to be checkable from
    # the URL alone.
    if API_KEY and key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")

    # Merge pattern from
    # https://www.mux.com/articles/merge-audio-and-video-files-with-ffmpeg —
    # one or two inputs mapped into a single mp4 output. Stream-copy when
    # the source codec is already iOS-safe (cheap, no re-encode); transcode
    # to h264/aac when it isn't (e.g. Instagram/Facebook VP9 or Opus), so
    # every file this endpoint returns is guaranteed playable regardless of
    # what the source offered.
    #
    # Written to a real temp file rather than piped to stdout: piping
    # requires `-movflags frag_keyframe+empty_moov` (no seeking back to
    # finalize a normal `moov` atom on a non-seekable pipe), and while
    # AVPlayer/video_player play a fragmented mp4 fine, iOS PhotoKit's
    # `PHAssetChangeRequest.creationRequestForAssetFromVideo` is strict
    # about resource validity and rejects it (PHPhotosError 3302). Writing
    # to a file lets ffmpeg finalize a standard, fully-seekable mp4 with
    # `+faststart` that both AVPlayer and PhotoKit accept.
    fd, output_path = tempfile.mkstemp(suffix=".mp4")
    os.close(fd)

    cmd = ["ffmpeg", "-y", "-i", video]
    if audio:
        cmd += ["-i", audio, "-map", "0:v:0", "-map", "1:a:0"]

    if _needs_video_transcode(vcodec):
        cmd += ["-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p"]
    else:
        cmd += ["-c:v", "copy"]

    if _needs_audio_transcode(acodec):
        cmd += ["-c:a", "aac", "-b:a", "128k"]
    else:
        cmd += ["-c:a", "copy"]

    cmd += ["-movflags", "+faststart", "-f", "mp4", output_path]

    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    if proc.returncode != 0 or not os.path.exists(output_path) or os.path.getsize(output_path) == 0:
        detail = proc.stdout.decode("utf-8", errors="replace")[-2000:].strip()
        logger.error(
            "ffmpeg failed (exit %s) for video=%s audio=%s: %s",
            proc.returncode, video, audio, detail or "(no output)",
        )
        if os.path.exists(output_path):
            os.remove(output_path)
        raise HTTPException(status_code=502, detail="Failed to prepare this file for playback.")

    def cleanup():
        if os.path.exists(output_path):
            os.remove(output_path)

    return FileResponse(output_path, media_type="video/mp4", background=BackgroundTask(cleanup))


@app.get("/health")
def health():
    return {"status": "ok"}
