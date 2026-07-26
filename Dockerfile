# syntax=docker/dockerfile:1

# ============================================================
# nso (Enchant Version of 9Router) — Railway Dockerfile
# Multi-stage build with pnpm (pinned to v10 for Node 20 compatibility)
# ============================================================

# ---- Stage 1: Dependencies (install production deps only) ----
FROM node:20-alpine AS deps
WORKDIR /app

# Install pnpm v10 (compatible with Node 20)
RUN npm install -g pnpm@10.34.5

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install production dependencies only (frozen lockfile for reproducibility)
RUN pnpm install --prod --frozen-lockfile && \
    pnpm store prune

# ---- Stage 2: Builder (build Next.js app) ----
FROM node:20-alpine AS builder
WORKDIR /app

# Install pnpm v10
RUN npm install -g pnpm@10.34.5

# Copy production node_modules from deps stage (optional: for cache)
COPY --from=deps /app/node_modules ./node_modules

# Copy source code
COPY . .

# Install ALL dependencies (including devDeps for build)
RUN pnpm install --frozen-lockfile

# Build Next.js application
RUN pnpm run build

# ---- Stage 3: Runner (production runtime) ----
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3000

# Create non-root user
RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 nso \
    && mkdir -p /data \
    && chown -R nso:nodejs /data

USER nso

# Copy production node_modules
COPY --from=deps --chown=nso:nodejs /app/node_modules ./node_modules

# Copy built Next.js output
COPY --from=builder --chown=nso:nodejs /app/.next ./.next
COPY --from=builder --chown=nso:nodejs /app/public ./public
COPY --from=builder --chown=nso:nodejs /app/package.json ./package.json
COPY --from=builder --chown=nso:nodejs /app/next.config.* ./

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

# Start server
CMD ["node", "server.js"]
