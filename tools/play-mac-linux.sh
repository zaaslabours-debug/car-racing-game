#!/bin/sh
cd "$(dirname "$0")"
echo "=================================================="
echo "  SILVER LAKE GP - starting game server..."
echo "  Keep this window open while playing."
echo "  Game opens at http://localhost:8080"
echo "=================================================="
( sleep 2; (xdg-open http://localhost:8080 >/dev/null 2>&1 || open http://localhost:8080 >/dev/null 2>&1) ) &
if command -v python3 >/dev/null 2>&1; then
  python3 -m http.server 8080
elif command -v python >/dev/null 2>&1; then
  python -m http.server 8080
elif command -v npx >/dev/null 2>&1; then
  npx --yes serve -l 8080 .
else
  echo "Python 3 was not found. Install it free from https://www.python.org and run this again."
fi
