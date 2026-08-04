#!/usr/bin/env bash
# Build and run the current checkout as an isolated local test stack.
# This stack uses separate container names, ports, network, and named volumes.

set -euo pipefail

WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE_COMPOSE_FILE="$WORK_DIR/docker-compose.yml"
TEST_OVERRIDE_FILE="$WORK_DIR/docker-compose.local-test.override.yml"
ENV_FILE="$WORK_DIR/.env"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-xianyu-local-test}"

if ! command -v docker >/dev/null 2>&1; then
    echo '错误: Docker 未安装。'
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo '错误: Docker Compose 未安装。'
    exit 1
fi

for file in "$BASE_COMPOSE_FILE" "$TEST_OVERRIDE_FILE" "$ENV_FILE"; do
    if [ ! -f "$file" ]; then
        echo "错误: 缺少文件 $file"
        exit 1
    fi
done

# Keep the test stack off the production ports used by the cloud-image stack.
export BACKEND_WEB_PORT="${LOCAL_TEST_BACKEND_WEB_PORT:-18089}"
export WEBSOCKET_PORT="${LOCAL_TEST_WEBSOCKET_PORT:-18090}"
export SCHEDULER_PORT="${LOCAL_TEST_SCHEDULER_PORT:-18091}"
export FRONTEND_PORT="${LOCAL_TEST_FRONTEND_PORT:-19000}"

COMPOSE=(
    docker compose
    --project-name "$PROJECT_NAME"
    --env-file "$ENV_FILE"
    -f "$BASE_COMPOSE_FILE"
    -f "$TEST_OVERRIDE_FILE"
)

echo '=========================================='
echo '  启动本地源码测试栈'
echo '=========================================='
echo "项目: $PROJECT_NAME"
echo "端口: frontend=$FRONTEND_PORT backend=$BACKEND_WEB_PORT websocket=$WEBSOCKET_PORT scheduler=$SCHEDULER_PORT"
echo

"${COMPOSE[@]}" up \
    -d \
    --build \
    --wait \
    --wait-timeout "${LOCAL_TEST_WAIT_TIMEOUT:-600}"
echo
"${COMPOSE[@]}" ps

echo
if command -v curl >/dev/null 2>&1; then
    check_url() {
        local name="$1"
        local url="$2"
        local status
        status="$(curl --noproxy '*' --silent --show-error --output /dev/null --write-out '%{http_code}' "$url")"
        if [ "$status" != '200' ]; then
            echo "错误: $name 返回 HTTP $status ($url)"
            exit 1
        fi
        echo "$name: HTTP $status ($url)"
    }

    echo 'HTTP 验证：'
    check_url '前端' "http://127.0.0.1:$FRONTEND_PORT/"
    check_url '后端' "http://127.0.0.1:$BACKEND_WEB_PORT/health"
    check_url 'WebSocket' "http://127.0.0.1:$WEBSOCKET_PORT/health"
    check_url '调度服务' "http://127.0.0.1:$SCHEDULER_PORT/health"
fi
