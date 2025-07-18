# ---- 第 1 阶段：安装依赖 ----
FROM node:20-alpine AS deps
RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# ---- 第 2 阶段：构建项目 ----
FROM node:20-alpine AS builder
RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV DOCKER_ENV=true
RUN pnpm run build

# ---- 第 3 阶段：生成运行时镜像 ----
FROM node:20-alpine AS runner

# 创建非 root 用户
RUN addgroup -g 1001 -S nodejs && adduser -u 1001 -S nextjs -G nodejs

WORKDIR /app
ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3000
ENV DOCKER_ENV=true

# 从 builder 阶段复制构建产物（确保这个 AS builder 存在）
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/start.js ./start.js
COPY --from=builder /app/config.json ./config.json

# 修复 public 权限
COPY --from=builder /app/public ./public
RUN chown -R nextjs:nodejs /app/public && chmod -R 777 /app/public

# 静态资源
COPY --from=builder /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
CMD ["node", "start.js"]
