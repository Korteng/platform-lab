# syntax=docker/dockerfile:1.7
# Фронтенд Finance Manager. Контекст: корень finance-manager. nginx.conf берётся из platform-lab.
FROM node:22-alpine AS build
WORKDIR /app
COPY frontend/package.json frontend/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY frontend/ .
ARG VITE_API_BASE_URL=http://localhost:8090
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
RUN npm run build

# unprivileged-вариант nginx: работает не от root, слушает 8080
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY --from=nginxconf nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/ >/dev/null || exit 1
