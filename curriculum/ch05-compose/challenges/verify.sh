#!/bin/bash
# Chapter 5 — The Symphony of Steam: Verification Script
# Exit 0 = all checks passed
# Exit 1 = one or more checks failed

set -euo pipefail

FAILED=0
PASS_COUNT=0
FAIL_COUNT=0

# ── Helpers ────────────────────────────────────────────────────────────────────

green()  { printf '\033[0;32m%s\033[0m\n' "$1"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$1"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$1"; }

pass() {
  green "  PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  red "  FAIL: $1"
  if [ -n "${2:-}" ]; then
    yellow "  HINT: $2"
  fi
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILED=1
}

check() {
  local description="$1"
  local command="$2"
  local hint="${3:-}"

  if eval "$command" > /dev/null 2>&1; then
    pass "$description"
  else
    fail "$description" "$hint"
  fi
}

# ── Locate the compose file ────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE=""

# Search for docker-compose.yml in the challenge directory and its parent
for candidate in \
  "$SCRIPT_DIR/docker-compose.yml" \
  "$SCRIPT_DIR/../docker-compose.yml" \
  "$(pwd)/docker-compose.yml"
do
  if [ -f "$candidate" ]; then
    COMPOSE_FILE="$candidate"
    break
  fi
done

if [ -z "$COMPOSE_FILE" ]; then
  echo ""
  red "=== Chapter 5 Verification ==="
  echo ""
  fail "docker-compose.yml not found" \
    "Create docker-compose.yml in the challenges/ directory or the ch05-compose/ directory."
  echo ""
  red "Verification failed: no Compose file found."
  exit 1
fi

COMPOSE_DIR="$(dirname "$COMPOSE_FILE")"

echo ""
yellow "=== Chapter 5: The Symphony of Steam ==="
yellow "=== Verification Script ==="
echo ""
echo "Using Compose file: $COMPOSE_FILE"
echo ""

# ── Challenge 1 checks: All four services running ─────────────────────────────

echo "--- Challenge 1: Full Stack ---"
echo ""

# Check services are running using docker compose ps
running_services() {
  local service="$1"
  docker compose -f "$COMPOSE_FILE" ps --status running --services 2>/dev/null | grep -q "^${service}$"
}

check \
  "Service 'postgres' is running" \
  "running_services postgres" \
  "Make sure postgres is defined in your docker-compose.yml and docker compose up -d has been run."

check \
  "Service 'redis' is running" \
  "running_services redis" \
  "Make sure redis is defined in your docker-compose.yml."

check \
  "Service 'backend' is running" \
  "running_services backend" \
  "The backend may have crashed on startup. Check: docker compose logs backend"

check \
  "Service 'frontend' is running" \
  "running_services frontend" \
  "Make sure frontend is defined with the correct build path."

check \
  "Frontend accessible on port 8080" \
  "curl -sf --max-time 5 http://localhost:8080 | grep -qi 'cloudbrew'" \
  "Is port 8080 mapped in your frontend service? Check: ports: ['8080:80']"

check \
  "Backend /health endpoint responds" \
  "curl -sf --max-time 5 http://localhost:3000/health | grep -q 'ok'" \
  "Is port 3000 mapped? Check: docker compose logs backend"

check \
  "Backend /api/coffees endpoint responds" \
  "curl -sf --max-time 5 http://localhost:3000/api/coffees | grep -q 'source'" \
  "The backend may not be connected to Postgres or Redis. Check: docker compose logs backend"

echo ""

# ── Challenge 2 checks: Health checks ─────────────────────────────────────────

echo "--- Challenge 2: Health Checks ---"
echo ""

postgres_container() {
  docker compose -f "$COMPOSE_FILE" ps -q postgres 2>/dev/null | head -1
}

redis_container() {
  docker compose -f "$COMPOSE_FILE" ps -q redis 2>/dev/null | head -1
}

check_health() {
  local service="$1"
  local get_id_fn="$2"
  local container_id
  container_id=$(eval "$get_id_fn")
  if [ -z "$container_id" ]; then
    return 1
  fi
  local status
  status=$(docker inspect "$container_id" --format '{{.State.Health.Status}}' 2>/dev/null || echo "none")
  [ "$status" = "healthy" ]
}

check \
  "Postgres has a health check configured and is 'healthy'" \
  "check_health postgres postgres_container" \
  "Add a healthcheck: block to the postgres service using pg_isready. Wait for it to become healthy."

check \
  "Redis has a health check configured and is 'healthy'" \
  "check_health redis redis_container" \
  "Add a healthcheck: block to the redis service using redis-cli ping."

# Check depends_on uses condition: service_healthy
check \
  "docker-compose.yml uses 'service_healthy' condition for backend depends_on" \
  "grep -q 'service_healthy' '$COMPOSE_FILE'" \
  "Update backend's depends_on to use 'condition: service_healthy' for postgres and redis."

echo ""

# ── Challenge 3 checks: Secrets and profiles ──────────────────────────────────

echo "--- Challenge 3: Secrets and Profiles ---"
echo ""

# Check for hardcoded passwords in compose file
check \
  "docker-compose.yml contains no hardcoded passwords (no literal 'password' values)" \
  "! grep -iE '^\s*[^#].*(password|secret|passwd):\s+[^$\{][^\s]+' '$COMPOSE_FILE'" \
  "Move secrets to a .env file. Use \${VARIABLE_NAME} references in docker-compose.yml instead."

# Check .env file exists (in compose dir or parent)
ENV_FILE=""
for candidate in \
  "$COMPOSE_DIR/.env" \
  "$COMPOSE_DIR/../.env"
do
  if [ -f "$candidate" ]; then
    ENV_FILE="$candidate"
    break
  fi
done

check \
  ".env file exists" \
  "[ -n '$ENV_FILE' ] && [ -f '$ENV_FILE' ]" \
  "Create a .env file in the same directory as your docker-compose.yml with your secret values."

# Check .env.example exists
ENV_EXAMPLE=""
for candidate in \
  "$COMPOSE_DIR/.env.example" \
  "$COMPOSE_DIR/../.env.example"
do
  if [ -f "$candidate" ]; then
    ENV_EXAMPLE="$candidate"
    break
  fi
done

check \
  ".env.example file exists" \
  "[ -n '$ENV_EXAMPLE' ] && [ -f '$ENV_EXAMPLE' ]" \
  "Create a .env.example file with placeholder values so other developers know what to configure."

# Check profiles are defined
check \
  "docker-compose.yml defines a 'dev' profile" \
  "grep -q 'profiles:' '$COMPOSE_FILE' && grep -A2 'profiles:' '$COMPOSE_FILE' | grep -q '\- dev'" \
  "Add a service (e.g. adminer) with 'profiles: [dev]' to your docker-compose.yml."

check \
  "docker-compose.yml defines a 'test' profile" \
  "grep -q 'profiles:' '$COMPOSE_FILE' && grep -A2 'profiles:' '$COMPOSE_FILE' | grep -q '\- test'" \
  "Add a test-runner service with 'profiles: [test]' to your docker-compose.yml."

# Check adminer starts with --profile dev
check \
  "adminer service starts with --profile dev" \
  "docker compose -f '$COMPOSE_FILE' --profile dev config --services 2>/dev/null | grep -q 'adminer'" \
  "Make sure your adminer service has 'profiles: [dev]' and is defined in docker-compose.yml."

echo ""

# ── Resource labeling check ────────────────────────────────────────────────────

echo "--- Resource Labels ---"
echo ""

check \
  "docker-compose.yml uses 'learn-docker-k8s' app label" \
  "grep -q 'learn-docker-k8s' '$COMPOSE_FILE'" \
  "Add labels to your services: app: learn-docker-k8s, chapter: ch05"

check \
  "docker-compose.yml uses 'ch05' chapter label" \
  "grep -q 'ch05' '$COMPOSE_FILE'" \
  "Add labels to your services: chapter: ch05"

echo ""

# ── Summary ────────────────────────────────────────────────────────────────────

TOTAL=$((PASS_COUNT + FAIL_COUNT))

if [ "$FAILED" -eq 0 ]; then
  green "============================================"
  green " All $TOTAL checks passed! Chapter 5 complete!"
  green "============================================"
  echo ""
  echo "You built a complete, health-checked, secret-safe Docker Compose"
  echo "stack for NoCappuccino. New developers can now run one command and"
  echo "be productive in minutes."
  echo ""
  echo "That coffee influencer is about to change everything. See you in Chapter 6."
  exit 0
else
  red "============================================"
  red " $FAIL_COUNT of $TOTAL checks failed."
  red "============================================"
  echo ""
  echo "$PASS_COUNT of $TOTAL checks passed."
  echo ""
  echo "Review the FAIL and HINT lines above, fix the issues, then run this script again."
  exit 1
fi
