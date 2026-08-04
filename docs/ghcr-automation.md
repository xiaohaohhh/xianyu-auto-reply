# Fork 自动同步与 GHCR 镜像

本 fork 使用两个 GitHub Actions 工作流：

1. `.github/workflows/sync-upstream.yml` 在北京时间每天 `00:01`、`06:01`、`12:01`、`18:01` 把
   `zhinianboke/xianyu-auto-reply:main` 合并进本 fork 的 `main`，也支持手动运行。
   工作流使用普通 Git merge，不会使用 `reset --hard` 或强制推送；如有冲突，fork
   保持原状并让工作流失败。
2. `.github/workflows/publish-images.yml` 在本 fork 的 `main` 或 `dev` 有新代码时构建并发布四个
   Linux 多架构镜像（`linux/amd64`、`linux/arm64`）。同步工作流在成功合并后直接调用它，
   因为 `GITHUB_TOKEN` 推送的提交不会再次触发普通的 `push` 工作流。

## 分支与部署渠道

- `main` 是上游同步与备份分支：同步任务只合并上游到此分支，并发布 `latest` 与
  `sha-<12 位提交号>` 镜像供参考和回退。
- `dev` 是本 fork 的长期运行与修复分支：只有主动推送到 `dev` 才会更新它；同步任务不会向
  `dev` 合并上游。它发布 `dev` 与 `dev-sha-<12 位提交号>` 镜像。
- 部署机将 `IMAGE_TAG=dev` 写入 `.env` 后，`scripts/update_from_ghcr.sh` 始终拉取
  `dev` 标签。上游更新到 `main` 不会改变正在使用的 `dev` 镜像。

`dev` 不合并回 `main`。当需要吸收某一项上游改动时，从 `main` 选择明确的提交并手动
`git cherry-pick <提交号>` 到 `dev`，完成修复验证后再部署新的 `dev` 镜像。

## 本地源码测试

修改 `dev` 源码后，先运行隔离的本地测试栈：

```bash
cd /mnt/d/hao/project/xianyu/xianyu-auto-reply
bash scripts/run_local_test.sh
```

该测试栈以当前 `:dev` 云端镜像作为依赖环境，并把工作区中的后端、WebSocket、调度源码
覆盖进测试镜像；前端使用当前源码重新编译后覆盖进 `:dev` 运行镜像。这样既验证当前源码，
又无需重复下载 Python、Chromium 等大型依赖。应用端口为 `19000`、`18089`、`18090`、
`18091`，并使用独立容器名、网络和命名卷。正在运行的 `:dev` 云端镜像栈继续使用
`9000`、`8089`、`8090`、`8091`。

第一次启动使用全新的测试数据库，需要创建全部数据表，因此后端进入健康状态可能需要数分钟；
测试覆盖配置已为首次初始化保留更长的健康检查窗口。启动脚本会等待所有服务健康，并自动
验证四个 HTTP 地址均返回 `200`。

默认基础镜像跟随 `.env` 中的 `IMAGE_REGISTRY` 与 `IMAGE_TAG`；可分别通过
`LOCAL_TEST_BACKEND_BASE_IMAGE`、`LOCAL_TEST_WEBSOCKET_BASE_IMAGE`、
`LOCAL_TEST_SCHEDULER_BASE_IMAGE`、`LOCAL_TEST_FRONTEND_BASE_IMAGE` 覆盖。前端编译阶段的
Node 镜像可通过 `LOCAL_TEST_NODE_BASE_IMAGE` 覆盖。

该轻量测试方式复用基础镜像中已经安装的 Python 与浏览器依赖，适用于业务源码和前端修改。
若修改了 `pyproject.toml` 中的依赖列表，应先为新依赖补充对应的本地构建验证，再发布新的
`dev` 镜像。

测试地址：

```text
http://127.0.0.1:19000/
http://127.0.0.1:18089/health
http://127.0.0.1:18090/health
http://127.0.0.1:18091/health
```

测试完成后停止本地栈：

```bash
bash scripts/stop_local_test.sh
```

确认本地测试通过后，再提交并推送 `dev`，由 Actions 构建新的 `:dev` 镜像；部署机运行
`bash scripts/update_from_ghcr.sh` 才会应用该镜像。

发布的镜像为：

```text
ghcr.io/xiaohaohhh/xianyu-frontend:latest
ghcr.io/xiaohaohhh/xianyu-backend-web:latest
ghcr.io/xiaohaohhh/xianyu-websocket:latest
ghcr.io/xiaohaohhh/xianyu-scheduler:latest
```

每次构建还会发布不可变的 `sha-<12 位提交号>` 标签，可在需要回滚时使用。

`dev` 渠道使用同一组镜像名，但标签为 `dev` 和 `dev-sha-<12 位提交号>`。

## 首次启用

将本次提交推送到 `xiaohaohhh/xianyu-auto-reply` 后，打开仓库的 **Actions** 页面，手动运行
`同步上游代码并发布镜像`。首次运行会合并当前上游新增代码并发布镜像。工作流不需要
额外的 Registry 密钥，使用仓库的 `GITHUB_TOKEN` 发布到 GHCR。

当前四个镜像已经验证可匿名拉取。若以后将容器包设为私有，先在服务器执行：

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u xiaohaohhh --password-stdin
```

令牌需要 `read:packages` 权限。

## 从源码构建切换为 GHCR 镜像

在原有部署服务器的仓库根目录运行：

```bash
bash scripts/update_from_ghcr.sh
```

该脚本组合 `docker-compose.yml` 和 `docker-compose.ghcr.override.yml`，仅拉取并重建四个应用服务，
不会重新从源码构建，也不会删除当前 Docker 命名卷。因此已有的 MySQL、Redis、日志、上传文件、
备份和浏览器数据继续沿用。

指定某个已验证版本或其他兼容 Registry 时：

```bash
IMAGE_TAG=sha-<12 位提交号> bash scripts/update_from_ghcr.sh
IMAGE_REGISTRY=ghcr.io/xiaohaohhh IMAGE_TAG=latest bash scripts/update_from_ghcr.sh
IMAGE_REGISTRY=ghcr.io/xiaohaohhh IMAGE_TAG=dev bash scripts/update_from_ghcr.sh
```

部署服务器是否自动应用新镜像与 GitHub 的构建分开：默认由管理员在确认构建成功后运行该脚本。若要
定时自动应用，可由服务器上的 cron 或系统服务定时执行同一脚本。
