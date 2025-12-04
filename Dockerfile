# ====================================================================
# 第一阶段：前端构建 (React)
# ====================================================================
FROM --platform=linux/arm/v7 node:18-alpine AS frontend-builder

RUN npm install -g pnpm

WORKDIR /app/frontend

COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY frontend/ ./
RUN pnpm run build

# ====================================================================
# 第二阶段：后端构建 (Go)
# ====================================================================
# 使用 arm32v7 官方 golang 镜像，避免 apk/git QEMU 报错
FROM arm32v7/golang:1.24-alpine AS backend-builder

WORKDIR /app/backend

# 复制 go.mod/go.sum 并下载依赖
COPY go.mod go.sum ./
RUN go mod download

# 复制后端源码
COPY . .

# 拷贝前端构建好的静态文件
COPY --from=frontend-builder /app/frontend/dist ./static

# 静态编译 Go 二进制 (ARMv7)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -a -o main ./cmd/api

# ====================================================================
# 第三阶段：最终运行镜像
# ====================================================================
FROM arm32v7/alpine:3.18

# 安装必要依赖（避免 QEMU apk 报错）
RUN apk add --no-cache ca-certificates tzdata

ENV TZ=Asia/Shanghai
WORKDIR /app

# 拷贝后端二进制和静态文件
COPY --from=backend-builder /app/backend/main .
COPY --from=backend-builder /app/backend/static ./static

# 创建数据目录
RUN mkdir -p /app/data

EXPOSE 8080
CMD ["./main"]
