#!/usr/bin/env bash
set -euo pipefail

# ─── Hexagonship Reset ───────────────────────────────────────────────
# Stops everything and cleans all build artifacts for a fresh start.
# Usage: ./reset.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo ">> Stopping containers and removing volumes..."
docker compose -f docker-compose.yml down -v 2>/dev/null || true
docker compose -f docker-compose-app.yml down -v 2>/dev/null || true
docker compose -f docker-compose-kafka.yml down -v 2>/dev/null || true

echo ">> Cleaning frontend..."
rm -rf ship-frontend/node_modules ship-frontend/dist ship-frontend/.angular

echo ">> Cleaning backend..."
cd ship-backend && mvn -q clean 2>/dev/null || true && cd ..

echo ""
echo ">> Reset complete. Run ./setup.sh to start fresh."
