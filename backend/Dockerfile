FROM node:24-alpine AS builder

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json tsconfig.json ./
RUN npm ci

# Copy backend source
COPY adonisrc.ts ace.js ./
COPY bin ./bin
COPY config ./config
COPY app ./app
COPY database ./database
COPY start ./start
COPY public ./public

# Build TypeScript to build/
RUN npx tsc

# Production runtime stage
FROM node:24-alpine

WORKDIR /app

# Install PostgreSQL client tools (pg_dump & psql for whole-system snapshots)
RUN apk add --no-cache postgresql16-client

COPY package*.json ./
RUN npm ci --omit=dev

# Copy compiled JavaScript directly to app root matching subpath imports
COPY --from=builder /app/build/. ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/ace.js ./ace.js
COPY docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod +x ./docker-entrypoint.sh

ENV NODE_ENV=production
ENV PORT=3333
ENV HOST=0.0.0.0

EXPOSE 3333

ENTRYPOINT ["./docker-entrypoint.sh"]
