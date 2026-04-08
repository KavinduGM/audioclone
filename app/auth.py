"""
API key store + FastAPI auth dependency.

Design:
- Keys live in api_keys.json next to the project root.
- Each key: {key, name, created_at, last_used_at}.
- Bootstrap mode: if no keys exist, auth is disabled so the user can
  access the UI and create the first key. Once any key exists,
  every endpoint (except /api/health) requires X-API-Key.
"""
import os
import json
import secrets
from datetime import datetime
from typing import Optional
from threading import Lock

from fastapi import Header, HTTPException

KEYS_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "api_keys.json")
_lock = Lock()


def _load() -> list[dict]:
    if not os.path.isfile(KEYS_FILE):
        return []
    try:
        with open(KEYS_FILE, "r") as f:
            data = json.load(f)
        if isinstance(data, list):
            return data
    except Exception:
        pass
    return []


def _save(keys: list[dict]) -> None:
    tmp = KEYS_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(keys, f, indent=2)
    os.replace(tmp, KEYS_FILE)
    try:
        # best-effort: restrict perms on posix
        os.chmod(KEYS_FILE, 0o600)
    except Exception:
        pass


def list_keys_safe() -> list[dict]:
    """Return keys with the secret partially masked for display."""
    with _lock:
        keys = _load()
    out = []
    for k in keys:
        raw = k.get("key", "")
        masked = raw[:8] + "…" + raw[-4:] if len(raw) > 14 else "•" * len(raw)
        out.append({
            "id": k.get("id"),
            "name": k.get("name", ""),
            "key_masked": masked,
            "key_full": raw,  # local tool — owner is allowed to see their own keys
            "created_at": k.get("created_at"),
            "last_used_at": k.get("last_used_at"),
        })
    return out


def create_key(name: str) -> dict:
    if not name.strip():
        raise ValueError("name required")
    new_key = "vct_" + secrets.token_urlsafe(32)
    entry = {
        "id": secrets.token_hex(6),
        "name": name.strip(),
        "key": new_key,
        "created_at": datetime.utcnow().isoformat() + "Z",
        "last_used_at": None,
    }
    with _lock:
        keys = _load()
        keys.append(entry)
        _save(keys)
    return entry


def delete_key(key_id: str) -> bool:
    with _lock:
        keys = _load()
        new = [k for k in keys if k.get("id") != key_id]
        if len(new) == len(keys):
            return False
        _save(new)
    return True


def any_keys_exist() -> bool:
    with _lock:
        return len(_load()) > 0


def _touch_last_used(key_value: str) -> None:
    with _lock:
        keys = _load()
        changed = False
        for k in keys:
            if k.get("key") == key_value:
                k["last_used_at"] = datetime.utcnow().isoformat() + "Z"
                changed = True
                break
        if changed:
            _save(keys)


def verify(key_value: Optional[str]) -> bool:
    if not key_value:
        return False
    with _lock:
        keys = _load()
    for k in keys:
        if secrets.compare_digest(k.get("key", ""), key_value):
            _touch_last_used(key_value)
            return True
    return False


# ---------- FastAPI dependency ----------
def require_auth(x_api_key: Optional[str] = Header(default=None)):
    """
    Enforce auth on a route.
    - If no keys exist yet (bootstrap mode): allow everything.
    - Otherwise: require a valid X-API-Key header.
    """
    if not any_keys_exist():
        return  # bootstrap: first-time setup
    if not verify(x_api_key):
        raise HTTPException(status_code=401, detail="Invalid or missing X-API-Key")
