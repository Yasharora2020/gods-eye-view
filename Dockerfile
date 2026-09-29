# God's Eye View — homelab container image.
#
# The image holds NO keys. Vite bakes GOOGLE_MAPS_API_KEY and CESIUM_ION_TOKEN
# into the JS bundle at build time, and this image is published from a public
# fork — so the bundle is built when the pod starts, from the k8s Secret.
# ponytail: ~3 s of `vite build` on every pod start. Upgrade path if that ever
# hurts: a private image with the keys passed as a CI build-arg.

# Pinned to the major that satisfies package.json engines (>=24.14.0 <25).
FROM node:24-bookworm-slim

# Puppeteer and sharp are QA-only. Skip Puppeteer's ~300 MB Chromium download;
# both stay in the lockfile so `npm ci` still matches it exactly.
ENV PUPPETEER_SKIP_DOWNLOAD=1

WORKDIR /app

# Dependency layer first so source edits don't reinstall Cesium every build.
# NOT --omit=dev: vite is a devDependency, and vite is the builder AND server.
COPY package.json package-lock.json ./
RUN npm ci && npm cache clean --force

COPY . .

# HOST=0.0.0.0 binds all interfaces AND flips vite's allowedHosts to true,
# which is what lets gev.geekery.work through. Keys and settings are read
# straight from process.env, so the k8s Secret/ConfigMap need no .env file.
ENV HOST=0.0.0.0

# uid/gid 1000, ships with the node image. Matches runAsUser in deployment.yaml.
# Files stay root-owned so the app can't rewrite its own code; everything it
# writes lands on the volumes mounted in deployment.yaml.
USER node

# `vite preview` serves dist/ AND every /api/* provider (each registers
# configurePreviewServer). The dev-only "Provider Settings" endpoint that
# writes keys to .env is deliberately absent in preview.
EXPOSE 4173
CMD ["sh", "-c", "node_modules/.bin/vite build --logLevel warn && exec node_modules/.bin/vite preview --port 4173 --strictPort"]
