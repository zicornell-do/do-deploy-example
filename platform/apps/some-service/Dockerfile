# Minimal production-ready Dockerfile for NestJS hello-world
# 1) Build stage
FROM node:18-alpine AS build
WORKDIR /app

# Install dependencies
COPY package.json package-lock.json* ./
RUN npm ci || npm install --no-audit --no-fund

# Copy sources and build
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# 2) Runtime stage
FROM node:18-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production \
    PORT=3000

# Only install production deps (none required for runtime in this minimal app)
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev || npm install --omit=dev --no-audit --no-fund

# Copy built artifacts
COPY --from=build /app/dist ./dist

# Run as non-root for safety
RUN addgroup -S nodegrp && adduser -S nodeusr -G nodegrp
USER nodeusr

EXPOSE 3000
CMD ["node", "dist/main.js"]
