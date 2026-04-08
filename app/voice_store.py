"""
Voice library: stores reference wavs + metadata on disk.
Each voice lives in voices/{voice_id}/ with reference.wav + meta.json.
"""
import os
import json
import uuid
import shutil
import subprocess
from datetime import datetime
from typing import Optional

VOICES_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "voices")
os.makedirs(VOICES_DIR, exist_ok=True)


def _voice_path(voice_id: str) -> str:
    return os.path.join(VOICES_DIR, voice_id)


def _prepare_reference(src_path: str, dst_path: str) -> None:
    """
    Convert input audio to a clean 24kHz mono WAV for XTTS cloning.
    Also trims to first 60s — XTTS only needs a short, clean sample;
    longer references slow inference with no quality gain.
    Requires ffmpeg.
    """
    cmd = [
        "ffmpeg", "-y",
        "-i", src_path,
        "-ac", "1",
        "-ar", "24000",
        "-t", "60",
        "-af", "loudnorm=I=-16:TP=-1.5:LRA=11",
        dst_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg failed: {result.stderr[-500:]}")


def create_voice(name: str, description: str, source_audio_path: str) -> dict:
    voice_id = uuid.uuid4().hex[:12]
    vdir = _voice_path(voice_id)
    os.makedirs(vdir, exist_ok=True)
    ref_path = os.path.join(vdir, "reference.wav")
    try:
        _prepare_reference(source_audio_path, ref_path)
    except Exception:
        shutil.rmtree(vdir, ignore_errors=True)
        raise
    meta = {
        "voice_id": voice_id,
        "name": name,
        "description": description,
        "created_at": datetime.utcnow().isoformat() + "Z",
    }
    with open(os.path.join(vdir, "meta.json"), "w") as f:
        json.dump(meta, f, indent=2)
    return meta


def list_voices() -> list[dict]:
    out = []
    if not os.path.isdir(VOICES_DIR):
        return out
    for vid in sorted(os.listdir(VOICES_DIR)):
        meta_file = os.path.join(VOICES_DIR, vid, "meta.json")
        if os.path.isfile(meta_file):
            try:
                with open(meta_file) as f:
                    out.append(json.load(f))
            except Exception:
                continue
    out.sort(key=lambda m: m.get("created_at", ""), reverse=True)
    return out


def get_voice(voice_id: str) -> Optional[dict]:
    meta_file = os.path.join(_voice_path(voice_id), "meta.json")
    if not os.path.isfile(meta_file):
        return None
    with open(meta_file) as f:
        return json.load(f)


def get_reference_wav(voice_id: str) -> Optional[str]:
    p = os.path.join(_voice_path(voice_id), "reference.wav")
    return p if os.path.isfile(p) else None


def delete_voice(voice_id: str) -> bool:
    vdir = _voice_path(voice_id)
    if os.path.isdir(vdir):
        shutil.rmtree(vdir)
        return True
    return False
