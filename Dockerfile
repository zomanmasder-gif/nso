# syntax=docker/dockerfile:1

# ===================================
# Stage 1: Dependencies
# ===================================
FROM node:24-alpine AS deps
WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./
RUN npm ci --only=production && \
    npm cache clean --force

# ===================================
# Stage 2: Builder
# ===================================
FROM node:24-alpine AS builder
WORKDIR /app

# Copy deps from stage 1
COPY --from=deps /app/node_modules ./node_modules

# Copy source code
COPY . .

# Build Next.js for production
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN npm run build

# ===================================
# Stage 3: Runner
# ===================================
FROM node:24-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV DATA_DIR=/data
ENV HOSTNAME=0.0.0.0

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 extremerouter && \
    mkdir -p /data && \
    chown -R extremerouter:nodejs /data

# Copy built artifacts
COPY --from=builder --chown=extremerouter:nodejs /app/package.json ./package.json
COPY --from=builder --chown=extremerouter:nodejs /app/package-lock.json ./package-lock.json
COPY --from=builder --chown=extremerouter:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=extremerouter:nodejs /app/.next ./.next
COPY --from=builder --chown=extremerouter:nodejs /app/public ./public

# Copy config files if needed
COPY --from=builder --chown=extremerouter:nodejs /app/next.config.js ./next.config.js 2>/dev/null || true
COPY --from=builder --chown=extremerouter:nodejs /app/next.config.mjs ./next.config.mjs 2>/dev/null || true

# Copy server-side runtime files (if any)
COPY --from=builder --chown=extremerouter:nodejs /app/src ./src 2>/dev/null || true
COPY --from=builder --chown=extremerouter:nodejs /app/lib ./lib 2>/dev/null || true

USER extremerouter

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD node -e "require('http').get('http://localhost:' + (process.env.PORT || 3000) + '/api/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1); }).on('error', () => process.exit(1));"

CMD ["npm", "run", "start"]
