#!/bin/bash
# [vroom-osrm-start 2026-05-09]
# Inicia OSRM em background (porta 5000) + vroom-express em foreground (porta 3000).
# Se OSRM morrer, mata o container — Fly.io reinicia tudo (fail-fast > zumbi).

set -euo pipefail

OSRM_DATA="/data/map.osrm"
OSRM_PORT=5000
VROOM_PORT="${PORT:-3000}"

if [ ! -f "${OSRM_DATA}" ]; then
  echo "FATAL: OSRM data file not found at ${OSRM_DATA}"
  echo "Container build deve ter rodado osrm-extract/partition/customize. Veja Dockerfile."
  exit 1
fi

echo "→ Starting osrm-routed on port ${OSRM_PORT} (algorithm=MLD)"
osrm-routed --algorithm mld --port ${OSRM_PORT} "${OSRM_DATA}" &
OSRM_PID=$!

# Espera OSRM responder (até 30s) — vroom-express vai bater logo de cara
echo "→ Waiting for OSRM to be ready..."
for i in $(seq 1 30); do
  if curl -sf "http://localhost:${OSRM_PORT}/route/v1/driving/-46.7,-23.5;-46.65,-23.55?overview=false" > /dev/null 2>&1; then
    echo "  OSRM ready after ${i}s"
    break
  fi
  if ! kill -0 $OSRM_PID 2>/dev/null; then
    echo "FATAL: osrm-routed died during startup"
    exit 1
  fi
  sleep 1
done

# Configura watchdog: se OSRM morrer, derruba o container inteiro
(
  wait $OSRM_PID
  echo "FATAL: osrm-routed exited unexpectedly. Killing container."
  kill 1
) &

echo "→ Starting vroom-express on port ${VROOM_PORT}"
exec node /app/src/index.js
