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

- `main` 是上游集成分支：同步任务只合并上游到此分支，并发布 `latest` 与
  `sha-<12 位提交号>` 镜像。
- `dev` 是本 fork 的修复分支：只有主动推送到 `dev` 才会更新它；同步任务不会向
  `dev` 合并上游。它发布 `dev` 与 `dev-sha-<12 位提交号>` 镜像。
- 部署机将 `IMAGE_TAG=dev` 写入 `.env` 后，`scripts/update_from_ghcr.sh` 始终拉取
  `dev` 标签。上游更新到 `main` 不会改变正在使用的 `dev` 镜像。

修复完成后，先将 `dev` 合并到 `main`，处理可能的上游冲突并完成验证；随后由 `main`
构建新的 `latest` 镜像。部署机需要切回 `IMAGE_TAG=latest` 才会跟随上游集成渠道。

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
