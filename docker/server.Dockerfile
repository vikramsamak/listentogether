# Stage 1: Dependencies - install production deps
FROM oven/bun:1.3.14 AS deps
WORKDIR /app

# Copy workspace configuration and lockfile for reproducible installs
COPY package.json bun.lock ./

# Copy package files maintaining workspace structure
COPY apps/server/package.json ./apps/server/package.json
COPY apps/client/package.json ./apps/client/package.json
COPY packages/shared/package.json ./packages/shared/package.json
# --ignore-scripts: the root prepare script runs lefthook (a devDependency,
# absent under --production install) and git hooks have no place in a container
RUN bun install --production --ignore-scripts --frozen-lockfile

# Stage 2: Build - bundle the server (bun start runs dist/index.js)
FROM deps AS build
WORKDIR /app
COPY apps/server/src ./apps/server/src
COPY apps/server/tsconfig.json ./apps/server/tsconfig.json
COPY packages/shared ./packages/shared
WORKDIR /app/apps/server
RUN bun run build

# Stage 3: Runner - final production image (self-contained bundle, no node_modules)
FROM oven/bun:1.3.14-slim AS runner
WORKDIR /app/apps/server

COPY --from=build /app/apps/server/dist ./dist

EXPOSE 8080
ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD ["bun", "-e", "fetch('http://127.0.0.1:8080/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]

CMD ["bun", "dist/index.js"]