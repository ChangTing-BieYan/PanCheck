# 第一阶段：前端
FROM --platform=linux/arm/v7 node:18-alpine AS frontend-builder
RUN npm install -g pnpm
WORKDIR /app/frontend
COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY frontend/ ./
RUN pnpm run build

# 第二阶段：后端
FROM --platform=linux/arm/v7 golang:1.24-alpine AS backend-builder
RUN apk add --no-cache git
WORKDIR /app/backend
COPY go.mod go.sum ./
RUN go mod download
COPY . .
COPY --from=frontend-builder /app/frontend/dist ./static
RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -a -o main ./cmd/api

# 第三阶段：运行镜像
FROM --platform=linux/arm/v7 alpine:latest
RUN apk --no-cache add ca-certificates tzdata libstdc++ libgcc
ENV TZ=Asia/Shanghai
WORKDIR /app
COPY --from=backend-builder /app/backend/main .
COPY --from=backend-builder /app/backend/static ./static
RUN mkdir -p /app/data
EXPOSE 8080
CMD ["./main"]
