#!/usr/bin/env bash
# Stop the isolated local test stack without deleting its named volumes.

set -euo pipefail

WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE_COMPOSE_FILE="$WORK_DIR/docker-compose.yml"
TEST_OVERRIDE_FILE="$WORK_DIR/docker-compose.local-test.override.yml"
ENV_FILE="$WORK_DIR/.env"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-xianyu-local-test}"

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    echo '错误: Docker Compose 未安装。'
    exit 1
fi

for file in "$BASE_COMPOSE_FILE" "$TEST_OVERRIDE_FILE" "$ENV_FILE"; do
    if [ ! -f "$file" ]; then
        echo "错误: 缺少文件 $file"
        exit 1
    fi
done

docker compose \
    --project-name "$PROJECT_NAME" \
    --env-file "$ENV_FILE" \
    -f "$BASE_COMPOSE_FILE" \
    -f "$TEST_OVERRIDE_FILE" \
    down
