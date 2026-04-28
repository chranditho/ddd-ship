#!/usr/bin/env bash
set -euo pipefail

# ─── Hexagonship Dev Setup ───────────────────────────────────────────
# Starts infrastructure (PostgreSQL + MinIO), uploads cat pictures,
# then runs the backend and frontend locally for development.
#
# Prerequisites: Docker, Java 21, Maven 3.9+, Node 24.x
# Usage: ./setup.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ─── 1. Start infrastructure ─────────────────────────────────────────
echo ">> Starting PostgreSQL and MinIO..."
docker compose -f docker-compose.yml up -d hexagonship-db minio

# ─── 2. Wait for MinIO ───────────────────────────────────────────────
echo ">> Waiting for MinIO..."
until curl -sf http://localhost:9000/minio/health/live > /dev/null 2>&1; do
  sleep 1
done
echo ">> MinIO is up."

# ─── 3. Wait for PostgreSQL ──────────────────────────────────────────
echo ">> Waiting for PostgreSQL..."
until docker exec hexagonship-db-postgres pg_isready -U hexagonship_user -d hexagonship > /dev/null 2>&1; do
  sleep 1
done
echo ">> PostgreSQL is up."

# ─── 4. Create bucket & upload cat images ────────────────────────────
echo ">> Setting up MinIO bucket and uploading cat pictures..."

docker run --rm --network host \
  --entrypoint sh minio/mc -c "
    mc alias set local http://localhost:9000 hexagonminio hexagonminio && \
    mc mb --ignore-existing local/catains && \
    echo 'Bucket catains ready.'
  "

IMAGE_IDS=(
  "58a6993f8b13de982e86845800d24d19"
  "60b8b2b44f0982a92b536b1d4ea0d1b8"
  "1c78951bdf46ddc00611b76089a53999"
  "eedaa2e1e5a36dbdd8611ba49de8053a"
  "eedaa2e1e5a36dbdd8611ba49de8053e"
)

# Cat images from the repo, mapped to each catain
CATAIN_IMAGES=(
  "$SCRIPT_DIR/ship-frontend/public/catains/furry_jones.jpeg"
  "$SCRIPT_DIR/ship-frontend/public/catains/bootstrap_bill.jpg"
  "$SCRIPT_DIR/ship-frontend/public/catains/catain_black_whiskers.png"
  "$SCRIPT_DIR/ship-frontend/public/catains/catain_cat_sparrow.png"
  "$SCRIPT_DIR/ship-frontend/public/catains/catain_cat_sparrow.png"
)

TMPDIR_CATS=$(mktemp -d)
trap 'rm -rf "$TMPDIR_CATS"' EXIT

echo ">> Preparing catain images..."
for i in "${!IMAGE_IDS[@]}"; do
  cp "${CATAIN_IMAGES[$i]}" "$TMPDIR_CATS/${IMAGE_IDS[$i]}"
done

echo ">> Uploading catain images to MinIO..."
docker run --rm --network host \
  -v "$TMPDIR_CATS:/cats:ro" \
  --entrypoint sh minio/mc -c "
    mc alias set local http://localhost:9000 hexagonminio hexagonminio
    for f in /cats/*; do
      mc cp \"\$f\" local/catains/\$(basename \"\$f\")
    done
    echo 'All catain images uploaded.'
    mc ls local/catains/
  "

# ─── 5. Build & start backend ─────────────────────────────────────────
# Kill any leftover processes on our ports
lsof -ti:8080 | xargs kill -9 2>/dev/null || true
lsof -ti:4200 | xargs kill -9 2>/dev/null || true

echo ">> Building backend (this may take a moment on first run)..."
cd "$SCRIPT_DIR/ship-backend"
mvn -q install -DskipTests
echo ">> Starting backend (Spring Boot)..."
mvn -q spring-boot:run -pl application -Dspring-boot.run.profiles=local &
BACKEND_PID=$!
cd "$SCRIPT_DIR"

echo ">> Waiting for backend..."
until curl -sf http://localhost:8080/web/catains > /dev/null 2>&1; do
  sleep 2
done
echo ">> Backend is up (PID $BACKEND_PID)."

# ─── 6. Start frontend ───────────────────────────────────────────────
echo ">> Installing frontend dependencies..."
cd "$SCRIPT_DIR/ship-frontend"
npm ci --silent
echo ">> Starting frontend (Angular dev server)..."
npx ng serve --proxy-config proxy.conf.json --open &
FRONTEND_PID=$!
cd "$SCRIPT_DIR"

# ─── Done ─────────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo "  Hexagonship dev environment is ready!"
echo "========================================="
echo "  Frontend:   http://localhost:4200"
echo "  Backend:    http://localhost:8080"
echo "  PostgreSQL: localhost:5432  (hexagonship_user / hexagonship_user)"
echo "  MinIO UI:   http://localhost:9001  (hexagonminio / hexagonminio)"
echo "========================================="
echo "  Backend PID:  $BACKEND_PID"
echo "  Frontend PID: $FRONTEND_PID"
echo ""
echo "  Press Ctrl+C to stop everything."

cleanup() {
  echo ""
  echo ">> Shutting down..."
  kill $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
  wait $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
  echo ">> Stopped backend and frontend. Infrastructure containers still running."
  echo "   Run 'docker compose down' to stop PostgreSQL and MinIO."
}
trap cleanup INT TERM

wait
