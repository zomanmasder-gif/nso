# syntax=docker/dockerfile:1

FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json ./
RUN npm install --production

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NODE_ENV=production
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV DATA_DIR=/data
ENV HOSTNAME=0.0.0.0

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nso && \
    mkdir -p /data && chown -R nso:nodejs /data

COPY --from=deps --chown=nso:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nso:nodejs /app/.next ./.next
COPY --from=builder --chown=nso:nodejs /app/public ./public
COPY --from=builder --chown=nso:nodejs /app/package.json ./package.json
COPY --from=builder --chown=nso:nodejs /app/next.config.* ./

USER nso
EXPOSE 3000
CMD ["npm", "start"]
