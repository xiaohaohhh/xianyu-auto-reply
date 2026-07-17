#!/usr/bin/env bash
# Pull and apply images built by this fork's GitHub Actions workflow.
# It reuses the source-build Compose configuration and therefore preserves the
# existing named volumes (MySQL, Redis, logs, uploads, backups, browser data).

set -euo pipefail

WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE_COMPOSE_FILE="$WORK_DIR/docker-compose.yml"
IMAGE_OVERRIDE_FILE="$WORK_DIR/docker-compose.ghcr.override.yml"
ENV_FILE="$WORK_DIR/.env"
APP_SERVICES=(backend-web websocket scheduler frontend)

if ! command -v docker >/dev/null 2>&1; then
    echo '错误: Docker 未安装。'
    exit 1
fi

if docker compose version >/dev/null 2>&1; then
    DC=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    DC=(docker-compose)
else
    echo '错误: Docker Compose 未安装。'
    exit 1
fi

if [ ! -f "$BASE_COMPOSE_FILE" ] || [ ! -f "$IMAGE_OVERRIDE_FILE" ]; then
    echo '错误: 缺少 Docker Compose 配置文件。'
    exit 1
fi

read_env_value() {
    local key="$1"
    [ -f "$ENV_FILE" ] || return 0
    grep -E "^${key}=" "$ENV_FILE" | tail -n 1 | cut -d '=' -f2- | tr -d '\r' || true
}

# Shell variables take priority; otherwise retain values already recorded in
# .env. A source-build .env normally has neither variable, so GHCR is used.
IMAGE_REGISTRY="${IMAGE_REGISTRY:-$(read_env_value IMAGE_REGISTRY)}"
IMAGE_TAG="${IMAGE_TAG:-$(read_env_value IMAGE_TAG)}"
export IMAGE_REGISTRY="${IMAGE_REGISTRY:-ghcr.io/xiaohaohhh}"
export IMAGE_TAG="${IMAGE_TAG:-latest}"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-xianyu-auto-reply}"

COMPOSE=("${DC[@]}" -f "$BASE_COMPOSE_FILE" -f "$IMAGE_OVERRIDE_FILE")
if [ -f "$ENV_FILE" ]; then
    COMPOSE+=(--env-file "$ENV_FILE")
fi

echo '=========================================='
echo '  从 GHCR 更新闲鱼自动回复服务'
echo '=========================================='
echo "镜像仓库: $IMAGE_REGISTRY"
echo "镜像标签: $IMAGE_TAG"
echo

"${COMPOSE[@]}" pull "${APP_SERVICES[@]}"
"${COMPOSE[@]}" up -d --no-build "${APP_SERVICES[@]}"

echo
echo '等待服务启动...'
sleep 15
"${COMPOSE[@]}" ps

echo
echo '更新完成。MySQL、Redis 和其他命名卷均未删除。'
