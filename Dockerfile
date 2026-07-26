# syntax=docker/dockerfile:1

# ==========================================
# nso (Enchant Version of 9Router) — Railway Dockerfile
# Multi-stage build with pnpm
# ==========================================

# ------------------------------------------
# Stage 1: Dependencies (deps)
# ------------------------------------------
FROM node:20-alpine AS deps
WORKDIR /app

# Install pnpm globally
RUN npm install -g pnpm

# Copy package manifest & lockfile
COPY package.json pnpm-lock.yaml ./

# Install production dependencies only (frozen lockfile for reproducibility)
RUN pnpm install --prod --frozen-lockfile && \
    pnpm store prune

# ------------------------------------------
# Stage 2: Builder (build Next.js / TypeScript)
# ------------------------------------------
FROM node:20-alpine AS builder
WORKDIR /app

# Install pnpm
RUN npm install -g pnpm

# Copy node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy source code
COPY . .

# Build the application
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN pnpm run build

# ------------------------------------------
# Stage 3: Runner (production runtime)
# ------------------------------------------
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV DATA_DIR=/data
ENV HOSTNAME=0.0.0.0

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nso && \
    mkdir -p /data && \
    chown -R nso:nodejs /data

# Install pnpm (needed if start script uses pnpm)
RUN npm install -g pnpm

# Copy production dependencies
COPY --from=deps --chown=nso:nodejs /app/node_modules ./node_modules

# Copy built application
COPY --from=builder --chown=nso:nodejs /app/.next ./.next
COPY --from=builder --chown=nso:nodejs /app/public ./public
COPY --from=builder --chown=nso:nodejs /app/package.json ./package.json
COPY --from=builder --chown=nso:nodejs /app/pnpm-lock.yaml ./pnpm-lock.yaml

# Copy Next.js config (if exists)
COPY --from=builder --chown=nso:nodejs /app/next.config.js ./next.config.js 2>/dev/null || true
COPY --from=builder --chown=nso:nodejs /app/next.config.mjs ./next.config.mjs 2>/dev/null || true
COPY --from=builder --chown=nso:nodejs /app/next.config.ts ./next.config.ts 2>/dev/null || true

# Copy server-side source if needed (for API routes, middleware, etc)
COPY --from=builder --chown=nso:nodejs /app/src ./src 2>/dev/null || true
COPY --from=builder --chown=nso:nodejs /app/lib ./lib 2>/dev/null || true
COPY --from=builder --chown=nso:nodejs /app/app ./app 2>/dev/null || true

USER nso

EXPOSE 3000

# Health check (adjust path if your app uses different health endpoint)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD node -e "require('http').get('http://localhost:' + (process.env.PORT || 3000) + '/api/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1); }).on('error', () => process.exit(1));"

# Start the application
CMD ["pnpm", "start"]