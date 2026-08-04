ARG NODE_BASE_IMAGE=docker.m.daocloud.io/library/node:18-alpine
ARG RUNTIME_IMAGE=ghcr.nju.edu.cn/xiaohaohhh/xianyu-frontend:dev

FROM ${NODE_BASE_IMAGE} AS builder

RUN npm config set registry https://registry.npmmirror.com
WORKDIR /app
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY frontend/ .
RUN npm run build

FROM ${RUNTIME_IMAGE}
RUN rm -rf /usr/share/nginx/html/*
COPY --from=builder /app/dist /usr/share/nginx/html
