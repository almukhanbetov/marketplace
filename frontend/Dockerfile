# ---- deps: install dependencies only (best layer-cache reuse) ----
FROM node:20-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

# ---- builder: production Next.js build ----
FROM node:20-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# NEXT_PUBLIC_* variables are inlined into the client bundle at build time,
# not read at container runtime — the production API origin must be passed
# as a build argument. No localhost fallback here: if it's not supplied,
# the build fails loudly instead of silently baking in a dev URL.
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NODE_ENV=production

# Guarantee a public/ dir exists so the COPY below never fails, whether or
# not the app actually has static assets to serve.
RUN mkdir -p public

RUN npm run build

# ---- runner: standalone runtime only ----
FROM node:20-alpine AS runner

RUN adduser -D -H -u 10001 appuser

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

# .next/standalone already contains a pruned node_modules (only what the
# server actually traced as used) plus a self-contained server.js.
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

USER appuser

EXPOSE 3000

CMD ["node", "server.js"]
