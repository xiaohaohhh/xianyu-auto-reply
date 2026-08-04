ARG BASE_IMAGE=ghcr.nju.edu.cn/xiaohaohhh/xianyu-backend-web:dev
FROM ${BASE_IMAGE}

RUN rm -rf /app/common /app/backend-web /app/launcher
COPY common /app/common
COPY backend-web /app/backend-web
COPY launcher /app/launcher
