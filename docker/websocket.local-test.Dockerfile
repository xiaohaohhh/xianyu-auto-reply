ARG BASE_IMAGE=ghcr.nju.edu.cn/xiaohaohhh/xianyu-websocket:dev
FROM ${BASE_IMAGE}

RUN rm -rf /app/common /app/websocket /app/launcher
COPY common /app/common
COPY websocket /app/websocket
COPY launcher /app/launcher
