#!/bin/bash
# Chapter 03: The Vanishing Beans — Challenge Verification
# Exit 0 = all checks passed
# Exit 1 = one or more checks failed

set -u

FAILED=0
CHAPTER="ch03"

echo "=== Chapter 03: The Vanishing Beans — Verification ==="
echo ""

# ─────────────────────────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────────────────────────

pass() {
    echo "PASS: $1"
}

fail() {
    echo "FAIL: $1"
    FAILED=1
}

hint() {
    echo "HINT: $1"
}

check() {
    local description="$1"
    local command="$2"
    if eval "$command" > /dev/null 2>&1; then
        pass "$description"
    else
        fail "$description"
    fi
}

# ─────────────────────────────────────────────────────────────
# Challenge 01: Survive the Restart
# ─────────────────────────────────────────────────────────────

echo "--- Challenge 01: Survive the Restart ---"
echo ""

# Check volume exists
if docker volume inspect learn-ch03-db-data > /dev/null 2>&1; then
    pass "Volume 'learn-ch03-db-data' exists"
else
    fail "Volume 'learn-ch03-db-data' not found"
    hint "Run: docker volume create --label app=learn-docker-k8s --label chapter=ch03 learn-ch03-db-data"
fi

# Check container is running
if docker ps --filter "name=learn-ch03-mysql" --filter "status=running" -q | grep -q .; then
    pass "Container 'learn-ch03-mysql' is running"
else
    fail "Container 'learn-ch03-mysql' is not running"
    hint "Make sure you recreated the container after deleting it, using -v learn-ch03-db-data:/var/lib/mysql"
fi

# Check MySQL is accepting connections (wait up to 30 seconds)
MYSQL_READY=0
for i in $(seq 1 6); do
    if docker exec learn-ch03-mysql mysqladmin ping -u root -pcloudbrewsecret --silent > /dev/null 2>&1; then
        MYSQL_READY=1
        break
    fi
    sleep 5
done

if [ "$MYSQL_READY" -eq 1 ]; then
    pass "MySQL is accepting connections"
else
    fail "MySQL is not responding"
    hint "MySQL may still be initializing. Wait 20-30 seconds and run verify.sh again."
fi

# Check the 'customers' table exists in the 'preferences' database
if docker exec learn-ch03-mysql \
    mysql -u root -pcloudbrewsecret -e "USE preferences; DESCRIBE customers;" > /dev/null 2>&1; then
    pass "Table 'customers' exists in 'preferences' database"
else
    fail "Table 'customers' not found in 'preferences' database"
    hint "Connect to MySQL and run: USE preferences; CREATE TABLE customers (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100), roast_preference VARCHAR(50));"
fi

# Check the 'customers' table has at least 1 row
ROW_COUNT=$(docker exec learn-ch03-mysql \
    mysql -u root -pcloudbrewsecret -sN -e "SELECT COUNT(*) FROM preferences.customers;" 2>/dev/null || echo "0")

if [ "$ROW_COUNT" -gt 0 ] 2>/dev/null; then
    pass "Table 'customers' has $ROW_COUNT row(s) — data survived container deletion"
else
    fail "Table 'customers' has no rows"
    hint "Insert a row: INSERT INTO preferences.customers (name, roast_preference) VALUES ('Alice', 'light roast');"
fi

echo ""

# ─────────────────────────────────────────────────────────────
# Challenge 02: Dev Hot Reload
# ─────────────────────────────────────────────────────────────

echo "--- Challenge 02: Dev Hot Reload ---"
echo ""

# Check container is running
if docker ps --filter "name=learn-ch03-node-app" --filter "status=running" -q | grep -q .; then
    pass "Container 'learn-ch03-node-app' is running"
else
    fail "Container 'learn-ch03-node-app' is not running"
    hint "Run your node:20-alpine container with -p 3000:3000 and a bind mount to your app directory"
fi

# Check port 3000 is accessible
if curl -sf http://localhost:3000 > /dev/null 2>&1; then
    pass "Port 3000 is accessible"
else
    fail "Port 3000 is not accessible"
    hint "Make sure you used -p 3000:3000 in your docker run command"
fi

# Check the container has a bind mount (not a named volume or anonymous)
MOUNTS=$(docker inspect learn-ch03-node-app --format '{{range .Mounts}}{{.Type}} {{end}}' 2>/dev/null || echo "")
if echo "$MOUNTS" | grep -q "bind"; then
    pass "Container uses a bind mount (host source code is live-linked)"
else
    fail "Container does not appear to use a bind mount"
    hint "Use -v /your/absolute/host/path:/app to bind mount your source code"
fi

# Test hot reload: capture current response, modify the file, check it changed
BIND_SOURCE=$(docker inspect learn-ch03-node-app \
    --format '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}{{end}}{{end}}' 2>/dev/null || echo "")

if [ -n "$BIND_SOURCE" ] && [ -f "$BIND_SOURCE/index.js" ]; then
    # Save original content
    ORIGINAL_CONTENT=$(cat "$BIND_SOURCE/index.js")
    ORIGINAL_RESPONSE=$(curl -sf http://localhost:3000 2>/dev/null || echo "")

    # Inject a unique marker into the greeting
    HOT_RELOAD_MARKER="HOT_RELOAD_TEST_$(date +%s)"
    # Replace the GREETING line with the test marker
    cleanup_sed() { [ -f "$BIND_SOURCE/index.js.bak" ] && mv "$BIND_SOURCE/index.js.bak" "$BIND_SOURCE/index.js" 2>/dev/null || true; }
    trap cleanup_sed EXIT
    sed -i.bak "s/const GREETING = .*/const GREETING = '$HOT_RELOAD_MARKER';/" "$BIND_SOURCE/index.js" 2>/dev/null || true

    # Wait for the file watcher to restart the process
    sleep 3

    NEW_RESPONSE=$(curl -sf http://localhost:3000 2>/dev/null || echo "")

    # Restore original content
    mv "$BIND_SOURCE/index.js.bak" "$BIND_SOURCE/index.js" 2>/dev/null || true

    if echo "$NEW_RESPONSE" | grep -q "$HOT_RELOAD_MARKER"; then
        pass "Response changed after file edit (hot reload is working)"
    else
        fail "Response did not change after file edit"
        hint "Make sure your container runs with 'node --watch index.js'. Check docker logs learn-ch03-node-app to see if restarts are happening."
    fi
else
    fail "Could not locate the bind-mounted source file to test hot reload"
    hint "Verify your bind mount path is correct and index.js exists in the mounted directory"
fi

echo ""

# ─────────────────────────────────────────────────────────────
# Challenge 03: Permission Debug
# ─────────────────────────────────────────────────────────────

echo "--- Challenge 03: Permission Debug ---"
echo ""

# Check fixed image exists
if docker image inspect learn-ch03-perm-app:fixed > /dev/null 2>&1; then
    pass "Image 'learn-ch03-perm-app:fixed' exists"
else
    fail "Image 'learn-ch03-perm-app:fixed' not found"
    hint "Build your fixed Dockerfile with: docker build -t learn-ch03-perm-app:fixed ."
fi

# Check the fixed image does NOT run as root
IMAGE_USER=$(docker inspect learn-ch03-perm-app:fixed --format '{{.Config.User}}' 2>/dev/null || echo "")
if [ -n "$IMAGE_USER" ] && [ "$IMAGE_USER" != "root" ] && [ "$IMAGE_USER" != "0" ]; then
    pass "Image 'learn-ch03-perm-app:fixed' runs as non-root user ($IMAGE_USER)"
else
    fail "Image 'learn-ch03-perm-app:fixed' appears to run as root (USER directive may be missing or set to root)"
    hint "Make sure USER appuser is present in your fixed Dockerfile"
fi

# Check volume exists
if docker volume inspect learn-ch03-app-logs > /dev/null 2>&1; then
    pass "Volume 'learn-ch03-app-logs' exists"
else
    fail "Volume 'learn-ch03-app-logs' not found"
    hint "Run: docker volume create --label app=learn-docker-k8s --label chapter=ch03 learn-ch03-app-logs"
fi

# Check container is running
if docker ps --filter "name=learn-ch03-logger" --filter "status=running" -q | grep -q .; then
    pass "Container 'learn-ch03-logger' is running"
else
    fail "Container 'learn-ch03-logger' is not running"
    hint "Run your learn-ch03-perm-app:fixed container with -v learn-ch03-app-logs:/app/logs -p 3000:3000"
fi

# Check port 3000 responds
if curl -sf http://localhost:3000 > /dev/null 2>&1; then
    pass "Port 3000 is accessible"
else
    fail "Port 3000 is not accessible"
    hint "Make sure you used -p 3000:3000 and the app started without errors (docker logs learn-ch03-logger)"
fi

# Check the log file was created inside the volume
LOG_EXISTS=$(docker run --rm \
    -v learn-ch03-app-logs:/check \
    alpine sh -c "[ -f /check/requests.log ] && echo yes || echo no" 2>/dev/null || echo "no")

if [ "$LOG_EXISTS" = "yes" ]; then
    pass "Log file 'requests.log' exists inside the volume"
else
    # Try making a request first to trigger a log write, then check again
    curl -sf http://localhost:3000 > /dev/null 2>&1 || true
    sleep 1
    LOG_EXISTS=$(docker run --rm \
        -v learn-ch03-app-logs:/check \
        alpine sh -c "[ -f /check/requests.log ] && echo yes || echo no" 2>/dev/null || echo "no")
    if [ "$LOG_EXISTS" = "yes" ]; then
        pass "Log file 'requests.log' exists inside the volume"
    else
        fail "Log file not found in volume 'learn-ch03-app-logs'"
        hint "If the app is running but the log file is missing, check that /app/logs inside the container is writable by appuser. Look at docker logs learn-ch03-logger for errors."
    fi
fi

echo ""

# ─────────────────────────────────────────────────────────────
# Final result
# ─────────────────────────────────────────────────────────────

if [ "$FAILED" -eq 0 ]; then
    echo "======================================"
    echo "All checks passed! Chapter 03 complete!"
    echo "======================================"
    echo ""
    echo "NoCappuccino customer data is safe. Dave is impressed."
    echo "Run 'bash engine/cleanup.sh' when you're ready to clean up ch03 resources."
    exit 0
else
    echo "======================================"
    echo "Some checks failed. Keep going — you've got this!"
    echo "======================================"
    echo ""
    echo "Review the HINT lines above and check:"
    echo "  docker ps -a --filter label=chapter=ch03"
    echo "  docker volume ls --filter label=chapter=ch03"
    echo "  docker logs <container-name>"
    exit 1
fi
