# ---- 第 1 阶段：安装依赖 ----
FROM node:20-alpine AS deps

# 启用 corepack 并激活 pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# 仅复制依赖清单，提高构建缓存利用率
COPY package.json pnpm-lock.yaml ./

# 安装所有依赖（含 devDependencies，后续会裁剪）
RUN pnpm install --frozen-lockfile

# ---- 第 2 阶段：构建项目 ----
FROM node:20-alpine AS builder
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# 复制依赖
COPY --from=deps /app/node_modules ./node_modules
# 复制全部源代码
COPY . .

# 替换所有 `runtime = 'edge'` 为 `runtime = 'nodejs'`
RUN find ./src -type f -name "route.ts" -print0 \
  | xargs -0 sed -i "s/export const runtime = 'edge';/export const runtime = 'nodejs';/g"

# 设置构建时环境变量
ENV DOCKER_ENV=true

# 强制 Next.js 使用动态渲染，支持运行时环境变量
RUN sed -i "/const inter = Inter({ subsets: \['latin'] });/a export const dynamic = 'force-dynamic';" src/app/layout.tsx

# 执行构建
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

# 从构建器复制生产构建内容
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/scripts ./scripts
COPY --from=builder --chown=nextjs:nodejs /app/start.js ./start.js
COPY --from=builder --chown=nextjs:nodejs /app/config.json ./config.json

# 复制 public 和静态资源目录，并授予写权限
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# ✅ 修复：确保 public 可写，避免 manifest.json 写入失败
RUN chmod -R u+w /app/public

# 切换到非 root 用户运行
USER nextjs

EXPOSE 3000

# 启动应用
CMD ["node", "start.js"]
