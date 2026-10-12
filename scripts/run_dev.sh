#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# An already-exported HYBRID_BACKEND_URL wins. Otherwise local API.
# Plain `flutter run` uses the same default (see AppConfig).
BACKEND="${HYBRID_BACKEND_URL:-http://localhost:3002}"

echo "Using backend: $BACKEND"
exec flutter run --dart-define=HYBRID_BACKEND_URL="$BACKEND" "$@"
