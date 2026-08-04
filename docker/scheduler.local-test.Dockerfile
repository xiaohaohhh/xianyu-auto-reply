ARG BASE_IMAGE=ghcr.nju.edu.cn/xiaohaohhh/xianyu-scheduler:dev
FROM ${BASE_IMAGE}

RUN rm -rf /app/common /app/scheduler /app/launcher
COPY common /app/common
COPY scheduler /app/scheduler
COPY launcher /app/launcher
