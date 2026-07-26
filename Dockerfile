# syntax=docker/dockerfile:1
# ==========================================
# nso (Enchant Version of 9Router) — Railway Dockerfile
# Multi-stage build with pnpm for production
# ==========================================
# -------- Stage 1: Dependencies --------
FROM node:20-alpine AS deps
WORKDIR /app
RUN npm install -g pnpm
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --prod --frozen-lockfile && pnpm store prune
# -------- Stage 2: Builder (for build script/ts/next) --------
FROM node:20-alpine AS builder
WORKDIR /app
RUN npm install -g pnpm
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm run build
# -------- Stage 3: Runner (release image) --------
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV DATA_DIR=/data
ENV HOSTNAME=0.0.0.0
# Security: non-root user
RUN addgroup --system --gid 1001 nodejs && \
 adduser --system --uid 1001 nso && \
 mkdir -p /data && \
 chown -R nso:nodejs /data
RUN npm install -g pnpm
# Copy runtime files — only what needed!
COPY --from=deps --chown=nso:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nso:nodejs /app/package.json ./package.json
COPY --from=builder --chown=nso:nodejs /app/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=builder --chown=nso:nodejs /app/.next ./.next 2>/dev/null || true
COPY --from=builder --chown=nso:nodejs /app/public ./public 2>/dev/null || true
COPY --from=builder --chown=nso:nodejs /app/dist ./dist 2>/dev/null || true
COPY --from=builder --chown=nso:nodejs /app/build ./build 2>/dev/null || true
COPY --from=builder --chown=nso:nodejs /app/next.config.js ./next.config.js 2>/dev/null || true
COPY --from=builder --chown=nso:nodejs /app/next.config.mjs ./next.config.mjs 2>/dev/null || true
COPY --from=builder --chown=nso:nodejs /app/next.config.ts ./next.config.ts 2>/dev/null || true
COPY --from=builder --chown=nso:nodejs /app/src ./src 2>/dev/null || true
COPY --from=builder --chown=nso:nodejs /app/lib ./lib 2>/dev/null || true
COPY --from=builder --chown=nso:nodejs /app/app ./app 2>/dev/null || true
USER nso
EXPOSE 3000
# Health check (bisa ganti ke endpoint lain sesuai app, misal: /dashboard)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
 CMD node -e "require('http').get('http://localhost:' + (process.env.PORT || 3000) + '/api/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1); }).on('error', () => process.exit(1));"
CMD ["pnpm", "start"]
