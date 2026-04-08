#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
  echo "==> Creating virtualenv"
  python3 -m venv .venv
fi
source .venv/bin/activate

echo "==> Installing dependencies (first run only)"
pip install --upgrade pip wheel setuptools > /dev/null

# Install torch once. On macOS this is the default wheel (MPS / CPU).
# On Linux + NVIDIA, uncomment the cu121 line instead for GPU support.
if ! python -c "import torch" 2>/dev/null; then
  pip install torch==2.3.1 torchaudio==2.3.1
  # pip install torch==2.3.1 torchaudio==2.3.1 --index-url https://download.pytorch.org/whl/cu121
fi

pip install -r requirements.txt

export COQUI_TOS_AGREED=1
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"

echo "==> Starting server on http://${HOST}:${PORT}"
exec uvicorn app.main:app --host "$HOST" --port "$PORT"
