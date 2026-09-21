# Stage 1: Dependencies - install all workspace deps (devDeps needed for next build)
FROM oven/bun:1.3.14 AS deps
WORKDIR /app

# Copy workspace configuration and lockfile for reproducible installs
COPY package.json bun.lock ./

# Copy package files maintaining workspace structure
COPY apps/client/package.json ./apps/client/package.json
COPY apps/server/package.json ./apps/server/package.json
COPY packages/shared/package.json ./packages/shared/package.json
RUN bun install --frozen-lockfile

# Stage 2: Build - bundle the Next.js client (standalone output)
FROM deps AS build
WORKDIR /app
COPY apps/client ./apps/client
COPY packages/shared ./packages/shared

# NEXT_PUBLIC_* values are inlined at build time
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_WS_URL
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_WS_URL=$NEXT_PUBLIC_WS_URL

WORKDIR /app/apps/client
RUN bun run build

# Stage 3: Runner - Node serves the self-contained standalone output
FROM node:24-alpine AS runner
WORKDIR /app

COPY --from=build /app/apps/client/.next/standalone ./
COPY --from=build /app/apps/client/.next/static ./apps/client/.next/static
COPY --from=build /app/apps/client/public ./apps/client/public

EXPOSE 3000
ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD ["node", "-e", "fetch('http://127.0.0.1:3000').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]

CMD ["node", "apps/client/server.js"]
