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
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/start.js ./start.js
COPY --from=builder /app/config.json ./config.json

# ✅ 复制 public，并手动修复权限（避免 Alpine 限制）
COPY --from=builder /app/public ./public

# ✅ 手动修复 public 的权限：授予写权限给 nextjs 用户
RUN chown -R nextjs:nodejs /app/public && chmod -R 777 /app/public

# ✅ 复制静态资源
COPY --from=builder /app/.next/static ./.next/static

# 切换到非 root 用户运行
USER nextjs

EXPOSE 3000

# 启动应用
CMD ["node", "start.js"]
